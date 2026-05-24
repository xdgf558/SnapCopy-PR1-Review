import Foundation

enum CaptionLanguage: String, Codable, CaseIterable, Identifiable {
    case englishUS = "en-US"
    case japanese = "ja-JP"
    case traditionalChinese = "zh-Hant"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .englishUS:
            "English"
        case .japanese:
            "日本語"
        case .traditionalChinese:
            "繁體中文"
        case .simplifiedChinese:
            "简体中文"
        }
    }

    var promptName: String {
        switch self {
        case .englishUS:
            "English (United States)"
        case .japanese:
            "Japanese"
        case .traditionalChinese:
            "Traditional Chinese"
        case .simplifiedChinese:
            "Simplified Chinese"
        }
    }

    var fallbackText: String {
        switch self {
        case .englishUS:
            "English captions"
        case .japanese:
            "日本語の文案"
        case .traditionalChinese:
            "繁體中文文案"
        case .simplifiedChinese:
            "简体中文文案"
        }
    }
}

struct UserPreference: Codable, Equatable {
    var styleWeights: [CaptionStyle: Double]
    var sceneStyleWeights: [String: [CaptionStyle: Double]]
    var textPreference: TextPreferenceProfile
    var preferredLanguages: [String]
    var preferredPlatforms: [SocialPlatform]
    var preferredLengthLevel: LengthLevel
    var dislikedPhrases: [String]
    var recommendationProfile: RecommendationPreferenceProfile
    var updatedAt: Date

    init(
        styleWeights: [CaptionStyle: Double],
        sceneStyleWeights: [String: [CaptionStyle: Double]] = [:],
        textPreference: TextPreferenceProfile = .default,
        preferredLanguages: [String],
        preferredPlatforms: [SocialPlatform],
        preferredLengthLevel: LengthLevel = .medium,
        dislikedPhrases: [String],
        recommendationProfile: RecommendationPreferenceProfile = .default,
        updatedAt: Date
    ) {
        self.styleWeights = styleWeights
        self.sceneStyleWeights = sceneStyleWeights
        self.textPreference = textPreference
        self.preferredLanguages = preferredLanguages
        self.preferredPlatforms = preferredPlatforms
        self.preferredLengthLevel = preferredLengthLevel
        self.dislikedPhrases = dislikedPhrases
        self.recommendationProfile = recommendationProfile
        self.updatedAt = updatedAt
    }

    static var `default`: UserPreference {
        UserPreference(
            styleWeights: Dictionary(uniqueKeysWithValues: CaptionStyle.allCases.map { ($0, 0.5) }),
            sceneStyleWeights: [:],
            textPreference: .default,
            preferredLanguages: ["zh-Hans"],
            preferredPlatforms: [.general],
            preferredLengthLevel: .medium,
            dislikedPhrases: [],
            recommendationProfile: .default,
            updatedAt: Date()
        )
    }
}

extension UserPreference {
    private enum CodingKeys: String, CodingKey {
        case styleWeights
        case sceneStyleWeights
        case textPreference
        case preferredLanguages
        case preferredPlatforms
        case preferredLengthLevel
        case dislikedPhrases
        case recommendationProfile
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        styleWeights = try container.decode([CaptionStyle: Double].self, forKey: .styleWeights)
        sceneStyleWeights = try container.decodeIfPresent([String: [CaptionStyle: Double]].self, forKey: .sceneStyleWeights) ?? [:]
        textPreference = try container.decodeIfPresent(TextPreferenceProfile.self, forKey: .textPreference) ?? .default
        preferredLanguages = try container.decode([String].self, forKey: .preferredLanguages)
        preferredPlatforms = try container.decode([SocialPlatform].self, forKey: .preferredPlatforms)
        preferredLengthLevel = try container.decodeIfPresent(LengthLevel.self, forKey: .preferredLengthLevel) ?? .medium
        dislikedPhrases = try container.decode([String].self, forKey: .dislikedPhrases)
        recommendationProfile = try container.decodeIfPresent(RecommendationPreferenceProfile.self, forKey: .recommendationProfile) ?? .default
        recommendationProfile.ensureDefaultKeys()
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

extension UserPreference {
    var cloudPreferenceSnapshot: CloudPreferenceSnapshot {
        CloudPreferenceSnapshot(
            preferredStyles: likedStylesForPrompt.prefix(6).map { $0 },
            avoidStyles: dislikedStylesForPrompt.prefix(6).map { $0 },
            likedPhrases: textPreference.likedPhrases.prefix(6).map { $0 },
            avoidPhrases: dislikedPhrasesForPrompt.prefix(8).map { $0 },
            preferredLengthLevel: preferredLengthLevel,
            preferredLanguage: preferredCaptionLanguage,
            preferredPlatforms: Array(preferredPlatforms.prefix(5)),
            sentenceShape: textPreference.sentenceShapePrompt,
            emojiPreference: textPreference.emojiPrompt,
            punctuationPreference: textPreference.punctuationPrompt
        )
    }

    var preferredCaptionLanguage: CaptionLanguage {
        preferredLanguages
            .compactMap(CaptionLanguage.init(rawValue:))
            .first ?? .simplifiedChinese
    }

    mutating func setPreferredCaptionLanguage(_ language: CaptionLanguage) {
        preferredLanguages = [language.rawValue]
        updatedAt = Date()
    }

    mutating func setPreferredPlatforms(_ platforms: [SocialPlatform]) {
        let normalizedPlatforms = platforms.isEmpty ? [.general] : platforms
        var uniquePlatforms: [SocialPlatform] = []

        for platform in normalizedPlatforms where !uniquePlatforms.contains(platform) {
            uniquePlatforms.append(platform)
        }

        preferredPlatforms = uniquePlatforms
        updatedAt = Date()
    }

    mutating func setPreferredLengthLevel(_ lengthLevel: LengthLevel) {
        preferredLengthLevel = lengthLevel
        updatedAt = Date()
    }

    var hasLearnedGenerationPreference: Bool {
        !likedStylesForGeneration.isEmpty ||
        !dislikedStylesForGeneration.isEmpty ||
        !sceneStyleWeights.isEmpty ||
        hasTextGenerationPreference ||
        !dislikedPhrases.isEmpty ||
        preferredPlatforms != [.general] ||
        preferredLengthLevel != .medium
    }

    var hasTextGenerationPreference: Bool {
        textPreference.hasLearnedPreference || !dislikedPhrases.isEmpty
    }

    var likedStylesForPrompt: [String] {
        likedStylesForGeneration.map(\.rawValue)
    }

    var dislikedStylesForPrompt: [String] {
        dislikedStylesForGeneration.map(\.rawValue)
    }

    var dislikedPhrasesForPrompt: [String] {
        Array(avoidedPhrasesForGeneration.prefix(8))
    }

    var generationPromptSummary: String {
        generationPromptSummary(for: .empty)
    }

    func generationPromptSummary(for context: CaptionGenerationContext) -> String {
        var lines: [String] = []

        let likedStyles = likedStylesForGeneration.map(\.promptName).joined(separator: ", ")
        let dislikedStyles = dislikedStylesForGeneration.map(\.promptName).joined(separator: ", ")
        let sceneLikedStyles = likedStylesForGeneration(context: context).map(\.promptName).joined(separator: ", ")
        let sceneDislikedStyles = dislikedStylesForGeneration(context: context).map(\.promptName).joined(separator: ", ")
        let platforms = preferredPlatforms.map(\.rawValue).joined(separator: ", ")
        let languages = preferredLanguages.joined(separator: ", ")
        let likedPhraseText = textPreference.likedPhrases.prefix(6).joined(separator: ", ")
        let dislikedPhraseText = avoidedPhrasesForGeneration.prefix(8).joined(separator: ", ")

        lines.append("preferredLanguages: \(languages.isEmpty ? "zh-Hans" : languages)")
        lines.append("preferredPlatforms: \(platforms.isEmpty ? "general" : platforms)")
        lines.append("preferredLengthLevel: \(preferredLengthLevel.rawValue)")

        if likedStyles.isEmpty {
            lines.append("likedStyles: none learned yet")
        } else {
            lines.append("likedStyles: \(likedStyles)")
        }

        if dislikedStyles.isEmpty {
            lines.append("avoidStyles: none learned yet")
        } else {
            lines.append("avoidStyles: \(dislikedStyles)")
        }

        if !dislikedPhraseText.isEmpty {
            lines.append("avoidPhrases: \(dislikedPhraseText)")
        }

        if !likedPhraseText.isEmpty {
            lines.append("likedPhrases: \(likedPhraseText)")
        }

        if let sentenceShape = textPreference.sentenceShapePrompt {
            lines.append("sentenceShape: \(sentenceShape)")
        }

        if let emojiPreference = textPreference.emojiPrompt {
            lines.append("emojiPreference: \(emojiPreference)")
        }

        if let punctuationPreference = textPreference.punctuationPrompt {
            lines.append("punctuationPreference: \(punctuationPreference)")
        }

        if !context.sceneTags.isEmpty {
            lines.append("sceneTagsForThisPhoto: \(context.promptSceneTags)")

            if sceneLikedStyles.isEmpty {
                lines.append("sceneLikedStyles: none learned for this scene yet")
            } else {
                lines.append("sceneLikedStyles: \(sceneLikedStyles)")
            }

            if sceneDislikedStyles.isEmpty {
                lines.append("sceneAvoidStyles: none learned for this scene yet")
            } else {
                lines.append("sceneAvoidStyles: \(sceneDislikedStyles)")
            }
        }

        lines.append("Rule: When sceneLikedStyles are present, prioritize them for this photo. Otherwise use likedStyles. Treat likedPhrases as tone examples, not mandatory repeated phrases. When avoidStyles, sceneAvoidStyles, avoidPhrases, or punctuationPreference are present, avoid them.")

        return lines.joined(separator: "\n")
    }

    func hasSceneSpecificGenerationPreference(for context: CaptionGenerationContext) -> Bool {
        !likedStylesForGeneration(context: context).isEmpty ||
        !dislikedStylesForGeneration(context: context).isEmpty
    }

    private var likedStylesForGeneration: [CaptionStyle] {
        sortedStyles(in: styleWeights) { $0.value >= 0.62 }
    }

    private var dislikedStylesForGeneration: [CaptionStyle] {
        Array(sortedStyles(in: styleWeights) { $0.value <= 0.38 }.reversed())
    }

    private var avoidedPhrasesForGeneration: [String] {
        var seen: Set<String> = []
        var phrases: [String] = []

        for phrase in textPreference.avoidedPhrases + dislikedPhrases {
            let normalizedPhrase = phrase.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !normalizedPhrase.isEmpty, !seen.contains(normalizedPhrase) else {
                continue
            }

            seen.insert(normalizedPhrase)
            phrases.append(normalizedPhrase)
        }

        return phrases
    }

    private func likedStylesForGeneration(context: CaptionGenerationContext) -> [CaptionStyle] {
        sortedStyles(in: sceneStyleWeights(for: context)) { $0.value >= 0.62 }
    }

    private func dislikedStylesForGeneration(context: CaptionGenerationContext) -> [CaptionStyle] {
        Array(sortedStyles(in: sceneStyleWeights(for: context)) { $0.value <= 0.38 }.reversed())
    }

    private func sortedStyles(
        in weights: [CaptionStyle: Double],
        where shouldInclude: (Dictionary<CaptionStyle, Double>.Element) -> Bool
    ) -> [CaptionStyle] {
        weights
            .filter(shouldInclude)
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key.rawValue < rhs.key.rawValue
                }

                return lhs.value > rhs.value
            }
            .map(\.key)
    }

    private func sceneStyleWeights(for context: CaptionGenerationContext) -> [CaptionStyle: Double] {
        let lookupTags = context.scenePreferenceLookupTags
        var valuesByStyle: [CaptionStyle: [Double]] = [:]

        for tag in lookupTags {
            guard let weights = sceneStyleWeights[tag] else {
                continue
            }

            for (style, value) in weights {
                valuesByStyle[style, default: []].append(value)
            }
        }

        return valuesByStyle.mapValues { values in
            values.reduce(0, +) / Double(values.count)
        }
    }
}

private extension CaptionStyle {
    var promptName: String {
        "\(rawValue) (\(displayName))"
    }
}

struct TextPreferenceProfile: Codable, Equatable {
    var phraseWeights: [String: Double]
    var shortCaptionWeight: Double
    var emojiWeight: Double
    var exclamationWeight: Double

    static let `default` = TextPreferenceProfile(
        phraseWeights: [:],
        shortCaptionWeight: 0.5,
        emojiWeight: 0.5,
        exclamationWeight: 0.5
    )
}

extension TextPreferenceProfile {
    var hasLearnedPreference: Bool {
        !likedPhrases.isEmpty ||
        !avoidedPhrases.isEmpty ||
        abs(shortCaptionWeight - 0.5) >= 0.12 ||
        abs(emojiWeight - 0.5) >= 0.12 ||
        abs(exclamationWeight - 0.5) >= 0.12
    }

    var likedPhrases: [String] {
        sortedPhrases { $0.value >= 0.62 }
    }

    var avoidedPhrases: [String] {
        Array(sortedPhrases { $0.value <= 0.38 }.reversed())
    }

    var sentenceShapePrompt: String? {
        if shortCaptionWeight >= 0.62 {
            return "prefer shorter, cleaner captions"
        }

        if shortCaptionWeight <= 0.38 {
            return "allow slightly longer, more complete captions"
        }

        return nil
    }

    var emojiPrompt: String? {
        if emojiWeight >= 0.62 {
            return "light emoji is welcome when natural"
        }

        if emojiWeight <= 0.38 {
            return "avoid emoji unless necessary"
        }

        return nil
    }

    var punctuationPrompt: String? {
        if exclamationWeight >= 0.62 {
            return "expressive punctuation is acceptable, but keep it natural"
        }

        if exclamationWeight <= 0.38 {
            return "avoid exclamation marks and overly excited punctuation"
        }

        return nil
    }

    private func sortedPhrases(
        where shouldInclude: (Dictionary<String, Double>.Element) -> Bool
    ) -> [String] {
        phraseWeights
            .filter(shouldInclude)
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key < rhs.key
                }

                return lhs.value > rhs.value
            }
            .map(\.key)
    }
}
