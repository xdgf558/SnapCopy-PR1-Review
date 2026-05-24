import Foundation

struct PreferenceEngine {
    private static let expressionMarkers = [
        "今天也要",
        "今日份",
        "小确幸",
        "氛围感",
        "松弛感",
        "生活感",
        "值得记录",
        "值得记住",
        "刚刚好",
        "慢慢",
        "好好生活",
        "治愈",
        "可爱",
        "打卡",
        "出逃"
    ]

    private static let phraseSeparators = CharacterSet(charactersIn: "，。！？、；：,.!?;:\n")
    private static let phraseTrimCharacters = CharacterSet.whitespacesAndNewlines
        .union(CharacterSet(charactersIn: "“”\"'‘’（）()[]【】《》<>，。！？、；：,.!?;:~～…"))

    func updatePreference(from event: RatingEvent, current: UserPreference) -> UserPreference {
        var updated = current
        let delta = delta(for: event.rating)

        for style in event.styleTags {
            let oldValue = updated.styleWeights[style] ?? 0.5
            updated.styleWeights[style] = min(1.0, max(0.0, oldValue + delta))
        }

        for sceneTag in normalizedSceneTags(from: event.sceneTags) {
            var sceneWeights = updated.sceneStyleWeights[sceneTag] ?? Dictionary(uniqueKeysWithValues: CaptionStyle.allCases.map { ($0, 0.5) })

            for style in event.styleTags {
                let oldValue = sceneWeights[style] ?? 0.5
                sceneWeights[style] = min(1.0, max(0.0, oldValue + delta))
            }

            updated.sceneStyleWeights[sceneTag] = sceneWeights
        }

        if let captionText = event.captionText {
            updateTextPreference(from: captionText, delta: delta, preference: &updated)
        }

        updated.updatedAt = Date()
        return updated
    }

    func sort(_ captions: [CaptionCandidate], using preference: UserPreference) -> [CaptionCandidate] {
        sort(captions, using: preference, context: .empty)
    }

    func sort(_ captions: [CaptionCandidate], using preference: UserPreference, context: CaptionGenerationContext) -> [CaptionCandidate] {
        captions.enumerated().sorted { lhs, rhs in
            let lhsWeight = score(for: lhs.element, using: preference, context: context)
            let rhsWeight = score(for: rhs.element, using: preference, context: context)

            if lhsWeight == rhsWeight {
                return lhs.offset < rhs.offset
            }

            return lhsWeight > rhsWeight
        }
        .map(\.element)
    }

    private func delta(for rating: Int) -> Double {
        switch rating {
        case 5:
            0.12
        case 4:
            0.06
        case 2:
            -0.06
        case 1:
            -0.12
        default:
            0.0
        }
    }

    private func score(for caption: CaptionCandidate, using preference: UserPreference, context: CaptionGenerationContext) -> Double {
        let styleScore = styleScore(for: caption, using: preference, context: context)

        guard preference.hasTextGenerationPreference else {
            return styleScore
        }

        let textScore = textScore(for: caption.text, using: preference)
        return styleScore * 0.75 + textScore * 0.25
    }

    private func styleScore(for caption: CaptionCandidate, using preference: UserPreference, context: CaptionGenerationContext) -> Double {
        let globalWeight = preference.styleWeights[caption.style] ?? 0.5
        let sceneTags = sceneLookupTags(for: caption, context: context)
        let sceneWeights = sceneTags.compactMap { tag in
            preference.sceneStyleWeights[tag]?[caption.style]
        }

        guard !sceneWeights.isEmpty else {
            return globalWeight
        }

        let sceneWeight = sceneWeights.reduce(0, +) / Double(sceneWeights.count)
        return sceneWeight * 0.7 + globalWeight * 0.3
    }

    private func textScore(for text: String, using preference: UserPreference) -> Double {
        let profile = preference.textPreference
        var signals: [Double] = []

        for phrase in expressionCandidates(from: text) {
            if let weight = profile.phraseWeights[phrase] {
                signals.append(weight)
            }
        }

        for dislikedPhrase in preference.dislikedPhrases where text.contains(dislikedPhrase) {
            signals.append(0.2)
        }

        if profile.shortCaptionWeight != 0.5 {
            if text.count <= 16 {
                signals.append(profile.shortCaptionWeight)
            } else if text.count >= 28 {
                signals.append(1 - profile.shortCaptionWeight)
            }
        }

        if profile.emojiWeight != 0.5 {
            signals.append(containsEmoji(text) ? profile.emojiWeight : 1 - profile.emojiWeight)
        }

        if profile.exclamationWeight != 0.5 {
            signals.append(containsExclamation(text) ? profile.exclamationWeight : 1 - profile.exclamationWeight)
        }

        guard !signals.isEmpty else {
            return 0.5
        }

        return signals.reduce(0, +) / Double(signals.count)
    }

    private func updateTextPreference(from text: String, delta: Double, preference: inout UserPreference) {
        guard delta != 0 else {
            return
        }

        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else {
            return
        }

        var profile = preference.textPreference
        let phrases = expressionCandidates(from: normalizedText)

        for phrase in phrases.prefix(8) {
            let oldValue = profile.phraseWeights[phrase] ?? 0.5
            profile.phraseWeights[phrase] = clamped(oldValue + delta)
        }

        if normalizedText.count <= 16 {
            profile.shortCaptionWeight = clamped(profile.shortCaptionWeight + delta)
        } else if normalizedText.count >= 28 {
            profile.shortCaptionWeight = clamped(profile.shortCaptionWeight - delta)
        }

        if containsEmoji(normalizedText) {
            profile.emojiWeight = clamped(profile.emojiWeight + delta)
        } else {
            profile.emojiWeight = clamped(profile.emojiWeight - delta * 0.5)
        }

        if containsExclamation(normalizedText) {
            profile.exclamationWeight = clamped(profile.exclamationWeight + delta)
        } else {
            profile.exclamationWeight = clamped(profile.exclamationWeight - delta * 0.5)
        }

        let strongPhrases = Array(phrases.prefix(5))
        if delta < 0 {
            for phrase in strongPhrases where !preference.dislikedPhrases.contains(phrase) {
                preference.dislikedPhrases.append(phrase)
            }

            if preference.dislikedPhrases.count > 30 {
                preference.dislikedPhrases = Array(preference.dislikedPhrases.suffix(30))
            }
        } else {
            preference.dislikedPhrases.removeAll { phrase in
                strongPhrases.contains(phrase)
            }
        }

        profile.phraseWeights = prunedPhraseWeights(profile.phraseWeights)
        preference.textPreference = profile
    }

    private func expressionCandidates(from text: String) -> [String] {
        var candidates: [String] = []

        for marker in Self.expressionMarkers where text.contains(marker) {
            candidates.append(marker)
        }

        let wholePhrase = normalizedPhrase(text)
        if wholePhrase.count >= 2, wholePhrase.count <= 18 {
            candidates.append(wholePhrase)
        }

        for fragment in text.components(separatedBy: Self.phraseSeparators) {
            let phrase = normalizedPhrase(fragment)

            guard phrase.count >= 2, phrase.count <= 18 else {
                continue
            }

            candidates.append(phrase)
        }

        var seen: Set<String> = []
        return candidates.compactMap { phrase in
            guard !seen.contains(phrase) else {
                return nil
            }

            seen.insert(phrase)
            return phrase
        }
    }

    private func normalizedPhrase(_ phrase: String) -> String {
        phrase
            .trimmingCharacters(in: Self.phraseTrimCharacters)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func containsEmoji(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            scalar.properties.isEmojiPresentation ||
            (scalar.properties.isEmoji && scalar.value > 0x2B00)
        }
    }

    private func containsExclamation(_ text: String) -> Bool {
        text.contains("!") || text.contains("！")
    }

    private func clamped(_ value: Double) -> Double {
        min(1.0, max(0.0, value))
    }

    private func prunedPhraseWeights(_ phraseWeights: [String: Double]) -> [String: Double] {
        Dictionary(
            uniqueKeysWithValues: phraseWeights
                .sorted { lhs, rhs in
                    abs(lhs.value - 0.5) > abs(rhs.value - 0.5)
                }
                .prefix(40)
                .map { ($0.key, $0.value) }
        )
    }

    private func sceneLookupTags(for caption: CaptionCandidate, context: CaptionGenerationContext) -> [String] {
        normalizedSceneTags(from: context.scenePreferenceLookupTags + [caption.scene.rawValue])
    }

    private func normalizedSceneTags(from tags: [String]) -> [String] {
        var seen: Set<String> = []

        return tags.compactMap { tag in
            let normalizedTag = tag
                .lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: " ", with: "-")

            guard !normalizedTag.isEmpty, normalizedTag != SceneType.unknown.rawValue, !seen.contains(normalizedTag) else {
                return nil
            }

            seen.insert(normalizedTag)
            return normalizedTag
        }
    }
}
