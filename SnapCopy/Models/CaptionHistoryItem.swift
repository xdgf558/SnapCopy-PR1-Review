import Foundation

enum CaptionHistoryInteraction: String, Codable, Equatable {
    case generated
    case copied
    case shared
    case favorited
}

struct CaptionHistoryItem: Identifiable, Codable {
    let id: UUID
    var caption: CaptionCandidate
    let createdAt: Date
    var lastUpdatedAt: Date
    var isFavorite: Bool
    var lastInteraction: CaptionHistoryInteraction
    var thumbnailData: Data?

    init(
        id: UUID = UUID(),
        caption: CaptionCandidate,
        createdAt: Date = Date(),
        lastUpdatedAt: Date = Date(),
        isFavorite: Bool = false,
        lastInteraction: CaptionHistoryInteraction = .generated,
        thumbnailData: Data? = nil
    ) {
        self.id = id
        self.caption = caption
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.isFavorite = isFavorite
        self.lastInteraction = lastInteraction
        self.thumbnailData = thumbnailData
    }
}
