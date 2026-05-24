import Foundation

final class RatingStore {
    private let eventsKey = "snapcopy.ratingEvents"
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func save(_ event: RatingEvent) {
        var events = loadEvents()
        events.append(event)

        guard let data = try? encoder.encode(events) else {
            return
        }

        userDefaults.set(data, forKey: eventsKey)
    }

    func loadEvents() -> [RatingEvent] {
        guard let data = userDefaults.data(forKey: eventsKey),
              let events = try? decoder.decode([RatingEvent].self, from: data) else {
            return []
        }

        return events
    }

    func applySavedRatings(to captions: [CaptionCandidate]) -> [CaptionCandidate] {
        captions.map { caption in
            var updatedCaption = caption
            updatedCaption.userRating = latestRating(for: caption.id)
            return updatedCaption
        }
    }

    private func latestRating(for captionId: UUID) -> Int? {
        loadEvents().last { $0.captionId == captionId }?.rating
    }
}
