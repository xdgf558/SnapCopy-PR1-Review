import Foundation

final class UserPreferenceStore {
    private let preferenceKey = "snapcopy.userPreference"
    private let recommendationFeedbackKey = "snapcopy.recommendationFeedbackEvents"
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let preferenceEngine: PreferenceEngine
    private let feedbackCollector: FeedbackCollector

    init(
        userDefaults: UserDefaults = .standard,
        preferenceEngine: PreferenceEngine = PreferenceEngine(),
        feedbackCollector: FeedbackCollector = FeedbackCollector()
    ) {
        self.userDefaults = userDefaults
        self.preferenceEngine = preferenceEngine
        self.feedbackCollector = feedbackCollector
    }

    func load() -> UserPreference {
        guard let data = userDefaults.data(forKey: preferenceKey),
              let preference = try? decoder.decode(UserPreference.self, from: data) else {
            return .default
        }

        return preference
    }

    func save(_ preference: UserPreference) {
        guard let data = try? encoder.encode(preference) else {
            return
        }

        userDefaults.set(data, forKey: preferenceKey)
    }

    @discardableResult
    func updatePreferredCaptionLanguage(_ language: CaptionLanguage) -> UserPreference {
        var preference = load()
        preference.setPreferredCaptionLanguage(language)
        save(preference)
        return preference
    }

    @discardableResult
    func updatePreferredPlatform(_ platform: SocialPlatform) -> UserPreference {
        var preference = load()
        preference.setPreferredPlatforms([platform])
        save(preference)
        return preference
    }

    @discardableResult
    func updatePreferredLengthLevel(_ lengthLevel: LengthLevel) -> UserPreference {
        var preference = load()
        preference.setPreferredLengthLevel(lengthLevel)
        save(preference)
        return preference
    }

    @discardableResult
    func update(from event: RatingEvent) -> UserPreference {
        let updatedPreference = preferenceEngine.updatePreference(from: event, current: load())
        save(updatedPreference)
        return updatedPreference
    }

    func loadRecommendationFeedbackEvents() -> [RecommendationFeedbackEvent] {
        guard let data = userDefaults.data(forKey: recommendationFeedbackKey),
              let events = try? decoder.decode([RecommendationFeedbackEvent].self, from: data) else {
            return []
        }

        return events
    }

    @discardableResult
    func update(fromRecommendationFeedback event: RecommendationFeedbackEvent) -> UserPreference {
        var events = loadRecommendationFeedbackEvents()
        events.append(event)
        events = Array(events.suffix(120))

        if let data = try? encoder.encode(events) {
            userDefaults.set(data, forKey: recommendationFeedbackKey)
        }

        var preference = load()
        preference.recommendationProfile = feedbackCollector.updatedPreference(
            from: event,
            current: preference.recommendationProfile
        )
        preference.updatedAt = Date()
        save(preference)
        return preference
    }
}
