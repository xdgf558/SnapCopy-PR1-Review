import Foundation

enum CreativeImageStyle: String, Codable, CaseIterable, Identifiable {
    case cuteHandDrawn
    case cover
    case xiaohongshuSticker

    var id: String { rawValue }

    var systemImageName: String {
        switch self {
        case .cuteHandDrawn:
            "paintpalette"
        case .cover:
            "rectangle.inset.filled"
        case .xiaohongshuSticker:
            "sparkles.rectangle.stack"
        }
    }

    func prompt(context: CaptionGenerationContext) -> String {
        let sceneLine = "Photo scene tags: \(Self.safeSceneTags(from: context.sceneTags))."
        let detailLine = Self.safeDetailLine(from: context.imageDescription)

        switch self {
        case .cuteHandDrawn:
            return """
            Create a cute hand-drawn sharing image inspired by the attached photo.
            Keep the main subject recognizable, soft, warm, friendly, and suitable for a social post.
            Avoid text, logos, watermarks, or realistic photo retouching.
            \(sceneLine)
            \(detailLine)
            """
        case .cover:
            return """
            Create a polished social cover image inspired by the attached photo.
            Make it clean, cover-ready, balanced, and visually strong with room for a title overlay.
            Avoid text, logos, watermarks, clutter, or fake brand elements.
            \(sceneLine)
            \(detailLine)
            """
        case .xiaohongshuSticker:
            return """
            Create a cute lifestyle sticker image inspired by the attached photo.
            Make it playful, soft, expressive, and suitable as a decorative sticker for a social post.
            Avoid text, logos, watermarks, and overly realistic rendering.
            \(sceneLine)
            \(detailLine)
            """
        }
    }

    private static func safeSceneTags(from tags: [String]) -> String {
        let safeTags = tags
            .map { safeEnglishText($0) }
            .filter { !$0.isEmpty }

        return safeTags.isEmpty ? "general lifestyle photo" : safeTags.joined(separator: ", ")
    }

    private static func safeDetailLine(from imageDescription: String?) -> String {
        guard let imageDescription else {
            return "Use the attached image as the visual reference."
        }

        let safeLines = imageDescription
            .components(separatedBy: .newlines)
            .filter { !$0.localizedCaseInsensitiveContains("Visible text OCR") }
            .map { safeEnglishText($0) }
            .filter { !$0.isEmpty }

        let summary = safeLines.joined(separator: " ")
        guard !summary.isEmpty else {
            return "Use the attached image as the visual reference."
        }

        return "Photo details: \(String(summary.prefix(220)))."
    }

    private static func safeEnglishText(_ text: String) -> String {
        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ,.-:;/()")
        let scalars = text.unicodeScalars.map { scalar in
            allowedCharacters.contains(scalar) ? Character(scalar) : " "
        }
        let cleanedText = String(scalars)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
