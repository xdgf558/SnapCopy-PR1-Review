import Foundation

struct CaptionQualityEvaluation: Equatable {
    let score: Double
    let reasons: [String]
}

struct CaptionQualityEvaluator {
    private let genericPhrases = [
        "好可爱",
        "很可爱",
        "太可爱",
        "很温暖",
        "很幸福",
        "感到温暖",
        "感到幸福",
        "美好时光",
        "小确幸",
        "今日份",
        "记录一下",
        "值得留下",
        "值得记住",
        "让人感到",
        "治愈",
        "陪伴",
        "生活中的小",
        "这一刻",
        "这个美好的",
        "温柔值得"
    ]

    private let childishPhrases = [
        "萌萌",
        "棒棒",
        "开心呀",
        "可可爱爱",
        "太棒啦",
        "真的好棒",
        "满满的幸福",
        "暖暖的"
    ]

    private let concreteLabelKeywords = [
        "cat": ["猫", "貓", "cat"],
        "dog": ["狗", "dog"],
        "plate": ["盘", "盤", "plate"],
        "tableware": ["餐具", "tableware"],
        "utensil": ["餐具", "叉", "刀", "utensil", "fork", "knife"],
        "food": ["食物", "餐", "饭", "菜", "food", "meal"],
        "coffee": ["咖啡", "coffee"],
        "cup": ["杯", "cup"],
        "laptop": ["电脑", "电脑", "laptop"],
        "desk": ["桌", "desk"],
        "street": ["街", "路", "street", "road"],
        "sky": ["天", "sky"],
        "building": ["楼", "建筑", "building"],
        "person": ["人", "穿", "身", "person"],
        "clothing": ["穿", "衣", "搭", "clothing", "outfit"],
        "sunset": ["日落", "晚霞", "sunset"],
        "plant": ["植物", "花", "树", "plant"]
    ]

    func evaluate(_ candidate: CaptionCandidate, context: CaptionGenerationContext) -> CaptionQualityEvaluation {
        let text = candidate.text.trimmingCharacters(in: .whitespacesAndNewlines)
        var score = 0.5
        var reasons: [String] = []

        let concreteMatches = concreteCueMatches(in: text, context: context)
        if concreteMatches >= 2 {
            score += 0.22
            reasons.append("uses multiple concrete photo cues")
        } else if concreteMatches == 1 {
            score += 0.10
            reasons.append("uses one concrete photo cue")
        } else if context.hasImageDetails {
            score -= 0.18
            reasons.append("too generic for a photo with visual details")
        }

        let genericPenalty = phrasePenalty(in: text, phrases: genericPhrases)
        if genericPenalty > 0 {
            score -= genericPenalty
            reasons.append("contains generic social caption phrases")
        }

        let childishPenalty = phrasePenalty(in: text, phrases: childishPhrases) * 1.2
        if childishPenalty > 0 {
            score -= childishPenalty
            reasons.append("sounds too childish")
        }

        if text.count < 8 {
            score -= 0.12
            reasons.append("too short to carry a point of view")
        } else if text.count <= 42 {
            score += 0.08
            reasons.append("concise adult social length")
        }

        if hasMeasuredTone(text) {
            score += 0.08
            reasons.append("measured adult tone")
        }

        if hasRepetitiveStructure(text) {
            score -= 0.10
            reasons.append("repetitive wording")
        }

        if containsTooManyEmoji(text) {
            score -= 0.08
            reasons.append("too many emoji")
        }

        if CaptionTextSanitizer().containsMetadataLeak(text) {
            score -= 0.35
            reasons.append("contains leaked metadata fields")
        }

        if reasons.isEmpty {
            reasons.append("neutral quality")
        }

        return CaptionQualityEvaluation(score: clamped(score), reasons: reasons)
    }

    func ranked(_ candidates: [CaptionCandidate], context: CaptionGenerationContext) -> [CaptionCandidate] {
        candidates.enumerated()
            .sorted { lhs, rhs in
                let lhsScore = evaluate(lhs.element, context: context).score
                let rhsScore = evaluate(rhs.element, context: context).score

                if lhsScore == rhsScore {
                    return lhs.offset < rhs.offset
                }

                return lhsScore > rhsScore
            }
            .map(\.element)
    }

    private func concreteCueMatches(in text: String, context: CaptionGenerationContext) -> Int {
        guard let analysis = context.analysisResult else {
            return 0
        }

        let normalizedText = text.lowercased()
        var matches: Set<String> = []

        for label in analysis.visionLabels.map({ $0.name.lowercased() }) {
            if let words = concreteLabelKeywords.first(where: { label.contains($0.key) })?.value,
               words.contains(where: { normalizedText.contains($0.lowercased()) }) {
                matches.insert(label)
            }
        }

        if analysis.featureFlags.hasPet, ["猫", "貓", "狗", "pet", "cat", "dog"].contains(where: { normalizedText.contains($0.lowercased()) }) {
            matches.insert("pet")
        }

        if analysis.featureFlags.hasFood, ["餐", "饭", "菜", "食物", "盘", "盤", "food", "plate"].contains(where: { normalizedText.contains($0.lowercased()) }) {
            matches.insert("food")
        }

        return matches.count
    }

    private func phrasePenalty(in text: String, phrases: [String]) -> Double {
        let hitCount = phrases.filter { text.localizedCaseInsensitiveContains($0) }.count
        return min(0.24, Double(hitCount) * 0.08)
    }

    private func hasMeasuredTone(_ text: String) -> Bool {
        let signals = ["刚好", "拿捏", "不多说", "认真", "松弛", "稳稳", "体面", "质感", "日常", "气氛", "分寸"]
        return signals.contains { text.localizedCaseInsensitiveContains($0) }
    }

    private func hasRepetitiveStructure(_ text: String) -> Bool {
        let separators = CharacterSet(charactersIn: "，。！？、；：,.!?;:\n")
        let fragments = text.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 2 }

        let uniqueFragments = Set(fragments)
        return fragments.count >= 3 && uniqueFragments.count <= fragments.count / 2
    }

    private func containsTooManyEmoji(_ text: String) -> Bool {
        let emojiCount = text.unicodeScalars.filter { scalar in
            scalar.properties.isEmojiPresentation ||
            (scalar.properties.isEmoji && scalar.value > 0x2B00)
        }.count

        return emojiCount >= 3
    }

    private func clamped(_ value: Double) -> Double {
        min(1.0, max(0.0, value))
    }
}
