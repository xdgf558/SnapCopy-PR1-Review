import Foundation

struct RecommendationPreferenceProfile: Codable, Equatable {
    var weights: [String: Double]
    var updatedAt: Date

    static var `default`: RecommendationPreferenceProfile {
        RecommendationPreferenceProfile(
            weights: Dictionary(uniqueKeysWithValues: defaultWeightKeys.map { ($0, 0.5) }),
            updatedAt: Date()
        )
    }

    static let defaultWeightKeys = [
        "style.humor",
        "style.healing",
        "style.premium",
        "style.xiaohongshu",
        "style.instagram",
        "style.daily",
        "style.concise",
        "style.poetic",
        "length.short",
        "length.medium",
        "length.long",
        "emoji.low",
        "emoji.medium",
        "scene.breakfast",
        "scene.cafe",
        "scene.walking",
        "scene.street",
        "scene.travel",
        "scene.pet",
        "scene.outfit",
        "scene.home",
        "scene.work",
        "scene.food",
        "language.en",
        "language.ja",
        "language.zhHant",
        "language.zhHans",
        "filter.natural",
        "filter.warm",
        "filter.clean"
    ]

    func weight(for key: String) -> Double {
        weights[key] ?? 0.5
    }

    mutating func updateWeight(for key: String, reward: Double, learningRate: Double = 0.08) {
        let currentValue = weight(for: key)
        weights[key] = Self.clamped(currentValue + reward * learningRate)
        updatedAt = Date()
    }

    mutating func ensureDefaultKeys() {
        for key in Self.defaultWeightKeys where weights[key] == nil {
            weights[key] = 0.5
        }
    }

    private static func clamped(_ value: Double) -> Double {
        min(1.0, max(0.0, value))
    }
}

struct CaptionFeatureVector: Codable, Equatable {
    let scene: String
    let style: String
    let tone: String
    let platform: String
    let length: String
    let emojiLevel: String
    let language: String
    let hashtagLevel: String

    var learningKeys: [String] {
        var keys = [
            "style.\(style)",
            "scene.\(scene)",
            "length.\(length)",
            "language.\(languageKey)"
        ]

        if emojiLevel == "light" {
            keys.append("emoji.low")
        } else if emojiLevel == "medium" {
            keys.append("emoji.medium")
        }

        if platform == SocialPlatform.instagram.rawValue {
            keys.append("style.instagram")
        }

        return keys.uniqued()
    }

    private var languageKey: String {
        switch language {
        case "en-US", "en":
            return "en"
        case "ja-JP", "ja":
            return "ja"
        case "zh-Hant":
            return "zhHant"
        default:
            return "zhHans"
        }
    }
}

enum RecommendationFeedbackKind: String, Codable, CaseIterable {
    case rating
    case copyCaption
    case shareCaption
    case editedFinalCaptionUsed
    case saveCaption
    case regenerate
    case deleteCaption
    case markExternalGoodFeedback
}

struct RecommendationFeedbackAction: Codable, Equatable {
    let kind: RecommendationFeedbackKind
    let rating: Int?

    static func rating(_ value: Int) -> RecommendationFeedbackAction {
        RecommendationFeedbackAction(kind: .rating, rating: value)
    }

    static let copyCaption = RecommendationFeedbackAction(kind: .copyCaption, rating: nil)
    static let shareCaption = RecommendationFeedbackAction(kind: .shareCaption, rating: nil)
    static let editedFinalCaptionUsed = RecommendationFeedbackAction(kind: .editedFinalCaptionUsed, rating: nil)
    static let saveCaption = RecommendationFeedbackAction(kind: .saveCaption, rating: nil)
    static let regenerate = RecommendationFeedbackAction(kind: .regenerate, rating: nil)
    static let deleteCaption = RecommendationFeedbackAction(kind: .deleteCaption, rating: nil)
    static let markExternalGoodFeedback = RecommendationFeedbackAction(kind: .markExternalGoodFeedback, rating: nil)
}

struct CaptionEditSummary: Codable, Equatable {
    let originalText: String
    let finalText: String
    let wasEdited: Bool
    let characterDelta: Int
    let emojiDelta: Int
    let addedPhrases: [String]
    let removedPhrases: [String]

    init(originalText: String, finalText: String) {
        let normalizedOriginal = originalText.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedFinal = finalText.trimmingCharacters(in: .whitespacesAndNewlines)
        let originalPhrases = Self.phrases(from: normalizedOriginal)
        let finalPhrases = Self.phrases(from: normalizedFinal)

        self.originalText = normalizedOriginal
        self.finalText = normalizedFinal
        self.wasEdited = normalizedOriginal != normalizedFinal
        self.characterDelta = normalizedFinal.count - normalizedOriginal.count
        self.emojiDelta = Self.emojiCount(in: normalizedFinal) - Self.emojiCount(in: normalizedOriginal)
        self.addedPhrases = Array(finalPhrases.subtracting(originalPhrases).prefix(8))
        self.removedPhrases = Array(originalPhrases.subtracting(finalPhrases).prefix(8))
    }

    private static func phrases(from text: String) -> Set<String> {
        let separators = CharacterSet(charactersIn: "，。！？、；：,.!?;:\n")
            .union(.whitespacesAndNewlines)
        let fragments = text
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 2 && $0.count <= 24 }

        if fragments.isEmpty, text.count >= 2, text.count <= 24 {
            return [text]
        }

        return Set(fragments)
    }

    private static func emojiCount(in text: String) -> Int {
        text.unicodeScalars.filter { scalar in
            scalar.properties.isEmojiPresentation ||
            (scalar.properties.isEmoji && scalar.value > 0x2B00)
        }
        .count
    }
}

struct RecommendationFeedbackEvent: Identifiable, Codable, Equatable {
    let id: UUID
    let captionId: UUID
    let action: RecommendationFeedbackAction
    let rewardScore: Double
    let dwellSeconds: Double?
    let editSummary: CaptionEditSummary?
    let features: CaptionFeatureVector
    let isExploration: Bool
    let createdAt: Date

    init(
        id: UUID = UUID(),
        captionId: UUID,
        action: RecommendationFeedbackAction,
        rewardScore: Double,
        dwellSeconds: Double? = nil,
        editSummary: CaptionEditSummary? = nil,
        features: CaptionFeatureVector,
        isExploration: Bool,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.captionId = captionId
        self.action = action
        self.rewardScore = rewardScore
        self.dwellSeconds = dwellSeconds
        self.editSummary = editSummary
        self.features = features
        self.isExploration = isExploration
        self.createdAt = createdAt
    }
}

struct RecommendationScoreComponent: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let value: Double
    let reason: String
}

struct ScoredCaptionRecommendation: Identifiable {
    let id: UUID
    let candidate: CaptionCandidate
    let features: CaptionFeatureVector
    let score: Double
    let scoreComponents: [RecommendationScoreComponent]
    let isExploration: Bool

    init(
        candidate: CaptionCandidate,
        features: CaptionFeatureVector,
        score: Double,
        scoreComponents: [RecommendationScoreComponent],
        isExploration: Bool = false
    ) {
        self.id = candidate.id
        self.candidate = candidate
        self.features = features
        self.score = score
        self.scoreComponents = scoreComponents
        self.isExploration = isExploration
    }

    var recommendationReason: String {
        let topReasons = scoreComponents
            .sorted { abs($0.value) > abs($1.value) }
            .prefix(3)
            .map(\.reason)

        guard !topReasons.isEmpty else {
            return "Default ranking."
        }

        return topReasons.joined(separator: " · ")
    }
}

struct FilterRecommendation: Equatable {
    let preset: ImageEnhancementPreset
    let score: Double
    let reasons: [String]
}

struct CaptionRecommendationResult {
    let rankedCaptions: [ScoredCaptionRecommendation]
    let recommendedFilter: FilterRecommendation
    let recentFeedback: [RecommendationFeedbackEvent]
    let preferenceSnapshot: RecommendationPreferenceProfile

    var candidates: [CaptionCandidate] {
        rankedCaptions.map(\.candidate)
    }
}

private extension Array where Element == String {
    func uniqued() -> [String] {
        var seen: Set<String> = []

        return filter { item in
            guard !seen.contains(item) else {
                return false
            }

            seen.insert(item)
            return true
        }
    }
}
