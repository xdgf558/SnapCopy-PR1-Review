import Foundation

struct LocalCaptionResponseParser {
    private let sanitizer = CaptionTextSanitizer()

    func parse(_ rawText: String) throws -> [CaptionCandidate] {
        let jsonText = try extractJSON(from: rawText)
        let data = Data(jsonText.utf8)
        let decoder = JSONDecoder()

        if let envelope = try? decoder.decode(LocalCaptionEnvelope.self, from: data) {
            return candidates(from: envelope.captions)
        }

        if let captions = try? decoder.decode([LocalCaptionDTO].self, from: data) {
            return candidates(from: captions)
        }

        throw LocalCaptionResponseParserError.invalidJSON
    }

    private func candidates(from captions: [LocalCaptionDTO]) -> [CaptionCandidate] {
        captions.prefix(5).compactMap { caption in
            guard let text = sanitizer.sanitizedText(from: caption.text) else {
                return nil
            }

            return CaptionCandidate(
                text: text,
                style: CaptionStyle(rawValue: caption.style ?? "") ?? .daily,
                platform: SocialPlatform(rawValue: caption.platform ?? "") ?? .general,
                lengthLevel: LengthLevel(rawValue: caption.lengthLevel ?? "") ?? .medium,
                emojiLevel: EmojiLevel(rawValue: caption.emojiLevel ?? "") ?? .none,
                scene: SceneType(rawValue: caption.scene ?? "") ?? .daily
            )
        }
    }

    private func extractJSON(from rawText: String) throws -> String {
        let trimmedText = rawText
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```JSON", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedText.first == "{" || trimmedText.first == "[" {
            return trimmedText
        }

        if let objectStart = trimmedText.firstIndex(of: "{"),
           let objectEnd = trimmedText.lastIndex(of: "}"),
           objectStart < objectEnd {
            return String(trimmedText[objectStart...objectEnd])
        }

        if let arrayStart = trimmedText.firstIndex(of: "["),
           let arrayEnd = trimmedText.lastIndex(of: "]"),
           arrayStart < arrayEnd {
            return String(trimmedText[arrayStart...arrayEnd])
        }

        throw LocalCaptionResponseParserError.missingJSON
    }
}

private struct LocalCaptionEnvelope: Decodable {
    let captions: [LocalCaptionDTO]
}

private struct LocalCaptionDTO: Decodable {
    let text: String
    let style: String?
    let platform: String?
    let lengthLevel: String?
    let emojiLevel: String?
    let scene: String?
}

enum LocalCaptionResponseParserError: Error {
    case missingJSON
    case invalidJSON
}
