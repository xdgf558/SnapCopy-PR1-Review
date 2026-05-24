import Foundation

struct UsageRecord: Codable, Equatable {
    var dayIdentifier: String
    var captionGenerations: Int
    var basicImageEnhancements: Int
    var cloudEnhancements: Int

    static func empty(dayIdentifier: String) -> UsageRecord {
        UsageRecord(
            dayIdentifier: dayIdentifier,
            captionGenerations: 0,
            basicImageEnhancements: 0,
            cloudEnhancements: 0
        )
    }
}

extension UsageRecord {
    private enum CodingKeys: String, CodingKey {
        case dayIdentifier
        case captionGenerations
        case basicImageEnhancements
        case cloudEnhancements
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dayIdentifier = try container.decode(String.self, forKey: .dayIdentifier)
        captionGenerations = try container.decode(Int.self, forKey: .captionGenerations)
        basicImageEnhancements = try container.decode(Int.self, forKey: .basicImageEnhancements)
        cloudEnhancements = try container.decodeIfPresent(Int.self, forKey: .cloudEnhancements) ?? 0
    }
}
