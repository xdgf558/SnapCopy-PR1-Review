import Foundation

enum CaptionStyle: String, Codable, CaseIterable, Identifiable {
    case healing
    case humor
    case premium
    case xiaohongshu
    case concise
    case poetic
    case daily

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .healing:
            "治愈"
        case .humor:
            "幽默"
        case .premium:
            "高级感"
        case .xiaohongshu:
            "小红书"
        case .concise:
            "简短"
        case .poetic:
            "文艺"
        case .daily:
            "日常"
        }
    }
}
