import Foundation

struct RatingEvent: Identifiable, Codable, Equatable {
    let id: UUID
    let captionId: UUID
    let captionText: String?
    let rating: Int
    let styleTags: [CaptionStyle]
    let sceneTags: [String]
    let platformHints: [SocialPlatform]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        captionId: UUID,
        captionText: String? = nil,
        rating: Int,
        styleTags: [CaptionStyle],
        sceneTags: [String],
        platformHints: [SocialPlatform],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.captionId = captionId
        self.captionText = captionText
        self.rating = rating
        self.styleTags = styleTags
        self.sceneTags = sceneTags
        self.platformHints = platformHints
        self.createdAt = createdAt
    }

    init(caption: CaptionCandidate, rating: Int) {
        self.init(
            captionId: caption.id,
            captionText: caption.text,
            rating: rating,
            styleTags: [caption.style],
            sceneTags: [caption.scene.rawValue],
            platformHints: [caption.platform]
        )
    }
}
