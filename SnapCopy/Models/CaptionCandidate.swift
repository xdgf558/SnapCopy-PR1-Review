import Foundation

struct CaptionCandidate: Identifiable, Codable {
    let id: UUID
    let text: String
    let style: CaptionStyle
    let platform: SocialPlatform
    let lengthLevel: LengthLevel
    let emojiLevel: EmojiLevel
    let scene: SceneType
    var userRating: Int?

    init(
        id: UUID = UUID(),
        text: String,
        style: CaptionStyle,
        platform: SocialPlatform = .general,
        lengthLevel: LengthLevel,
        emojiLevel: EmojiLevel,
        scene: SceneType = .unknown,
        userRating: Int? = nil
    ) {
        self.id = id
        self.text = text
        self.style = style
        self.platform = platform
        self.lengthLevel = lengthLevel
        self.emojiLevel = emojiLevel
        self.scene = scene
        self.userRating = userRating
    }
}

extension CaptionCandidate {
    func withPlatform(_ platform: SocialPlatform) -> CaptionCandidate {
        CaptionCandidate(
            id: id,
            text: text,
            style: style,
            platform: platform,
            lengthLevel: lengthLevel,
            emojiLevel: emojiLevel,
            scene: scene,
            userRating: userRating
        )
    }

    func withLengthLevel(_ lengthLevel: LengthLevel) -> CaptionCandidate {
        CaptionCandidate(
            id: id,
            text: text,
            style: style,
            platform: platform,
            lengthLevel: lengthLevel,
            emojiLevel: emojiLevel,
            scene: scene,
            userRating: userRating
        )
    }

    func withText(_ text: String) -> CaptionCandidate {
        CaptionCandidate(
            id: id,
            text: text,
            style: style,
            platform: platform,
            lengthLevel: lengthLevel,
            emojiLevel: emojiLevel,
            scene: scene,
            userRating: userRating
        )
    }
}

enum SocialPlatform: String, Codable, CaseIterable, Identifiable {
    case general
    case wechat
    case xiaohongshu
    case instagram
    case x

    var id: String { rawValue }

    var systemImageName: String {
        switch self {
        case .general:
            "sparkles"
        case .wechat:
            "bubble.left.and.bubble.right"
        case .xiaohongshu:
            "book.closed"
        case .instagram:
            "camera"
        case .x:
            "xmark"
        }
    }

    var promptGuidance: String {
        switch self {
        case .general:
            "General: natural, useful for most social apps, not too platform-specific."
        case .wechat:
            "WeChat Moments: warm, life-like, friendly, suitable for people who know the user; avoid salesy wording and overly dramatic hashtags."
        case .xiaohongshu:
            "Xiaohongshu: lifestyle note style, concrete detail, lightly polished, can use one natural emoji when appropriate; avoid fake product-review tone."
        case .instagram:
            "Instagram: concise, polished, visual-first, clean rhythm, suitable for photo-forward sharing."
        case .x:
            "X: short, direct, slightly witty when natural; avoid long paragraphs and heavy emoji."
        }
    }
}

enum LengthLevel: String, Codable, CaseIterable, Identifiable {
    case short
    case medium
    case long

    var id: String { rawValue }

    var systemImageName: String {
        switch self {
        case .short:
            "text.alignleft"
        case .medium:
            "text.justify"
        case .long:
            "text.append"
        }
    }

    var promptGuidance: String {
        switch self {
        case .short:
            "Short: write one clean sentence, roughly 8-18 English words or 10-25 CJK characters. Keep it punchy and easy to post."
        case .medium:
            "Natural: write one to two natural sentences, roughly 18-40 English words or 25-60 CJK characters. This should feel like a normal social caption."
        case .long:
            "Detailed: write two to four complete sentences, roughly 40-90 English words or 60-120 CJK characters. Add more mood, context, and a gentle narrative arc without becoming a long essay."
        }
    }
}

enum EmojiLevel: String, Codable, CaseIterable, Identifiable {
    case none
    case light
    case medium

    var id: String { rawValue }
}

enum SceneType: String, Codable, CaseIterable, Identifiable {
    case breakfast
    case cafe
    case walking
    case food
    case street
    case travel
    case pet
    case outfit
    case fitness
    case sunset
    case home
    case work
    case daily
    case unknown

    var id: String { rawValue }
}
