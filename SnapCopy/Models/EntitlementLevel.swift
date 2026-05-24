import Foundation

enum EntitlementLevel: String, Codable, CaseIterable, Identifiable {
    case free
    case plus
    case pro

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .free:
            "Free"
        case .plus:
            "Plus"
        case .pro:
            "Pro"
        }
    }

    var dailyCaptionGenerationLimit: Int? {
        switch self {
        case .free:
            100
        case .plus:
            nil
        case .pro:
            nil
        }
    }

    var dailyBasicImageEnhancementLimit: Int? {
        nil
    }

    func dailyCloudEnhancementLimit(isTestUser: Bool = false) -> Int {
        switch self {
        case .free:
            isTestUser ? 3 : 0
        case .plus:
            20
        case .pro:
            50
        }
    }

    var shortDescription: String {
        switch self {
        case .free:
            "基础体验"
        case .plus:
            "创作者预览"
        case .pro:
            "专业能力预览"
        }
    }
}
