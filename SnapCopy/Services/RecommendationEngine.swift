import Foundation

struct RecommendationEngine {
    private let featureExtractor = CaptionFeatureExtractor()
    private let qualityEvaluator = CaptionQualityEvaluator()
    private let explorationStrategy = ExplorationStrategy()

    func recommend(
        candidates: [CaptionCandidate],
        context: CaptionGenerationContext,
        targetPlatform: SocialPlatform,
        preference: RecommendationPreferenceProfile,
        recentFeedback: [RecommendationFeedbackEvent],
        targetLanguage: CaptionLanguage
    ) -> CaptionRecommendationResult {
        var normalizedPreference = preference
        normalizedPreference.ensureDefaultKeys()

        let scoredCaptions = candidates.map { candidate in
            let platformAdjustedCandidate = candidate.withPlatform(targetPlatform)
            let features = featureExtractor.extract(
                from: platformAdjustedCandidate,
                context: context,
                targetLanguage: targetLanguage
            )
            let components = scoreComponents(
                candidate: platformAdjustedCandidate,
                for: features,
                context: context,
                targetPlatform: targetPlatform,
                preference: normalizedPreference,
                recentFeedback: recentFeedback
            )
            let score = components.reduce(0) { $0 + $1.value }

            return ScoredCaptionRecommendation(
                candidate: platformAdjustedCandidate,
                features: features,
                score: score,
                scoreComponents: components
            )
        }

        let displayBatch = explorationStrategy.selectDisplayBatch(from: scoredCaptions)
        let filterRecommendation = recommendFilter(
            context: context,
            preference: normalizedPreference,
            recentFeedback: recentFeedback
        )

        return CaptionRecommendationResult(
            rankedCaptions: displayBatch,
            recommendedFilter: filterRecommendation,
            recentFeedback: Array(recentFeedback.suffix(12)),
            preferenceSnapshot: normalizedPreference
        )
    }

    private func scoreComponents(
        candidate: CaptionCandidate,
        for features: CaptionFeatureVector,
        context: CaptionGenerationContext,
        targetPlatform: SocialPlatform,
        preference: RecommendationPreferenceProfile,
        recentFeedback: [RecommendationFeedbackEvent]
    ) -> [RecommendationScoreComponent] {
        var components: [RecommendationScoreComponent] = []
        let qualityEvaluation = qualityEvaluator.evaluate(candidate, context: context)

        components.append(RecommendationScoreComponent(
            label: "Writing quality",
            value: (qualityEvaluation.score - 0.5) * 0.34,
            reason: qualityEvaluation.reasons.prefix(2).joined(separator: ", ")
        ))

        components.append(component(
            label: "Style",
            rawWeight: preference.weight(for: "style.\(features.style)"),
            multiplier: 0.36,
            reason: "style.\(features.style)"
        ))

        if features.platform == SocialPlatform.instagram.rawValue {
            components.append(component(
                label: "Instagram style",
                rawWeight: preference.weight(for: "style.instagram"),
                multiplier: 0.12,
                reason: "instagram platform style"
            ))
        }

        components.append(component(
            label: "Scene",
            rawWeight: preference.weight(for: "scene.\(features.scene)"),
            multiplier: 0.26,
            reason: "scene.\(features.scene)"
        ))

        components.append(component(
            label: "Length",
            rawWeight: preference.weight(for: "length.\(features.length)"),
            multiplier: 0.16,
            reason: "length.\(features.length)"
        ))

        if let emojiKey = emojiPreferenceKey(for: features.emojiLevel) {
            components.append(component(
                label: "Emoji",
                rawWeight: preference.weight(for: emojiKey),
                multiplier: 0.10,
                reason: emojiKey
            ))
        }

        components.append(component(
            label: "Language",
            rawWeight: preference.weight(for: "language.\(languageKey(for: features.language))"),
            multiplier: 0.12,
            reason: "language.\(languageKey(for: features.language))"
        ))

        if features.platform == targetPlatform.rawValue {
            components.append(RecommendationScoreComponent(
                label: "Platform match",
                value: 0.10,
                reason: "matches selected \(targetPlatform.rawValue)"
            ))
        }

        let recentScore = recentFeedbackBoost(for: features, recentFeedback: recentFeedback)
        if recentScore != 0 {
            components.append(RecommendationScoreComponent(
                label: "Recent feedback",
                value: recentScore,
                reason: recentScore > 0 ? "recent similar positive feedback" : "recent similar negative feedback"
            ))
        }

        return components
    }

    private func component(
        label: String,
        rawWeight: Double,
        multiplier: Double,
        reason: String
    ) -> RecommendationScoreComponent {
        let centered = rawWeight - 0.5
        return RecommendationScoreComponent(
            label: label,
            value: centered * multiplier,
            reason: "\(reason) weight \(formatted(rawWeight))"
        )
    }

    private func recentFeedbackBoost(
        for features: CaptionFeatureVector,
        recentFeedback: [RecommendationFeedbackEvent]
    ) -> Double {
        let matchedEvents = recentFeedback.suffix(20).filter { event in
            event.features.style == features.style ||
            event.features.scene == features.scene ||
            event.features.length == features.length
        }

        guard !matchedEvents.isEmpty else {
            return 0
        }

        let averageReward = matchedEvents.map(\.rewardScore).reduce(0, +) / Double(matchedEvents.count)
        return max(-0.12, min(0.12, averageReward * 0.08))
    }

    private func recommendFilter(
        context: CaptionGenerationContext,
        preference: RecommendationPreferenceProfile,
        recentFeedback: [RecommendationFeedbackEvent]
    ) -> FilterRecommendation {
        let scene = context.analysisResult?.sceneResolution.scene.rawValue ?? context.primaryScene.rawValue
        let visualTraits = context.analysisResult?.visualTraits
        let presets = ImageEnhancementPreset.allCases.map { preset in
            filterScore(
                preset,
                scene: scene,
                visualTraits: visualTraits,
                preference: preference,
                recentFeedback: recentFeedback
            )
        }

        return presets.max { lhs, rhs in
            lhs.score < rhs.score
        } ?? FilterRecommendation(preset: .natural, score: 0, reasons: ["Default natural style"])
    }

    private func filterScore(
        _ preset: ImageEnhancementPreset,
        scene: String,
        visualTraits: ImageVisualTraits?,
        preference: RecommendationPreferenceProfile,
        recentFeedback: [RecommendationFeedbackEvent]
    ) -> FilterRecommendation {
        let filterKey = "filter.\(preset.rawValue)"
        let filterWeight = preference.weight(for: filterKey)
        var score = (filterWeight - 0.5) * 0.30
        var reasons = ["\(filterKey) weight \(formatted(filterWeight))"]

        switch preset {
        case .warm:
            if ["cafe", "breakfast", "pet", "home", "sunset", "food"].contains(scene) {
                score += 0.14
                reasons.append("warm fits \(scene)")
            }

            if visualTraits?.colorTemperature == .warm {
                score += 0.08
                reasons.append("keeps warm light")
            }
        case .clean:
            if ["work", "outfit", "street"].contains(scene) {
                score += 0.14
                reasons.append("clean fits \(scene)")
            }

            if visualTraits?.saturation == .vivid {
                score += 0.05
                reasons.append("balances vivid color")
            }
        case .natural:
            score += 0.05
            reasons.append("safe default")
        }

        let filterFeedback = recentFeedback.suffix(20).map(\.rewardScore).reduce(0, +)
        if filterFeedback > 0 {
            score += min(0.05, filterFeedback * 0.005)
        }

        return FilterRecommendation(preset: preset, score: score, reasons: reasons)
    }

    private func emojiPreferenceKey(for emojiLevel: String) -> String? {
        switch emojiLevel {
        case "light":
            "emoji.low"
        case "medium":
            "emoji.medium"
        default:
            nil
        }
    }

    private func languageKey(for language: String) -> String {
        switch language {
        case "en-US", "en":
            "en"
        case "ja-JP", "ja":
            "ja"
        case "zh-Hant":
            "zhHant"
        default:
            "zhHans"
        }
    }

    private func formatted(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
