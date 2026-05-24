import Foundation

enum ImageEnhancementPreset: String, Codable, CaseIterable, Identifiable {
    case natural
    case warm
    case clean

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .natural:
            "Natural"
        case .warm:
            "Warm"
        case .clean:
            "Clean"
        }
    }
}
