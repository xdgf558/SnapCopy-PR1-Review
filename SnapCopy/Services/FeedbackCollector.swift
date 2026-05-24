import Foundation

struct FeedbackCollector {
    func rewardScore(for action: RecommendationFeedbackAction) -> Double {
        baseRewardScore(for: action)
    }

    func rewardScore(for action: RecommendationFeedbackAction, dwellSeconds: Double?) -> Double {
        let baseScore = baseRewardScore(for: action)
        let adjustment = dwellAdjustment(for: baseScore, action: action, dwellSeconds: dwellSeconds)
        return clamped(baseScore + adjustment)
    }

    private func baseRewardScore(for action: RecommendationFeedbackAction) -> Double {
        switch action.kind {
        case .rating:
            rewardScore(forRating: action.rating ?? 3)
        case .copyCaption:
            0.7
        case .shareCaption:
            0.9
        case .editedFinalCaptionUsed:
            1.3
        case .saveCaption:
            0.6
        case .regenerate:
            -0.4
        case .deleteCaption:
            -0.6
        case .markExternalGoodFeedback:
            1.2
        }
    }

    func makeEvent(
        caption: CaptionCandidate,
        action: RecommendationFeedbackAction,
        context: CaptionGenerationContext,
        targetLanguage: CaptionLanguage,
        isExploration: Bool,
        dwellSeconds: Double? = nil,
        editSummary: CaptionEditSummary? = nil
    ) -> RecommendationFeedbackEvent {
        let features = CaptionFeatureExtractor().extract(
            from: caption,
            context: context,
            targetLanguage: targetLanguage
        )

        return RecommendationFeedbackEvent(
            captionId: caption.id,
            action: action,
            rewardScore: rewardScore(for: action, dwellSeconds: dwellSeconds),
            dwellSeconds: dwellSeconds.map { rounded($0) },
            editSummary: editSummary,
            features: features,
            isExploration: isExploration
        )
    }

    func updatedPreference(
        from event: RecommendationFeedbackEvent,
        current profile: RecommendationPreferenceProfile
    ) -> RecommendationPreferenceProfile {
        var updatedProfile = profile
        updatedProfile.ensureDefaultKeys()

        let learningRate = event.isExploration ? 0.11 : 0.08

        for key in event.features.learningKeys {
            updatedProfile.updateWeight(for: key, reward: event.rewardScore, learningRate: learningRate)
        }

        updatedProfile.updatedAt = Date()
        return updatedProfile
    }

    private func rewardScore(forRating rating: Int) -> Double {
        switch rating {
        case 5:
            1.0
        case 4:
            0.6
        case 3:
            0.1
        case 2:
            -0.4
        case 1:
            -1.0
        default:
            0.0
        }
    }

    private func dwellAdjustment(
        for baseScore: Double,
        action: RecommendationFeedbackAction,
        dwellSeconds: Double?
    ) -> Double {
        guard let dwellSeconds, dwellSeconds >= 2, baseScore != 0 else {
            return 0
        }

        let cappedSeconds = min(max(dwellSeconds, 0), 45)
        let strength: Double

        switch cappedSeconds {
        case 2..<6:
            strength = 0.05
        case 6..<15:
            strength = 0.12
        case 15..<30:
            strength = 0.20
        default:
            strength = 0.25
        }

        if action.kind == .rating, action.rating == 3 {
            return min(strength, 0.05)
        }

        return baseScore > 0 ? strength : -strength
    }

    private func clamped(_ value: Double) -> Double {
        min(1.35, max(-1.25, value))
    }

    private func rounded(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }
}
