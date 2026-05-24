import Foundation

struct CaptionTextSanitizer {
    private static let metadataTokens: Set<String> = [
        "healing",
        "humor",
        "premium",
        "xiaohongshu",
        "concise",
        "poetic",
        "daily",
        "general",
        "wechat",
        "instagram",
        "x",
        "short",
        "medium",
        "long",
        "none",
        "light",
        "food",
        "street",
        "travel",
        "pet",
        "work",
        "unknown"
    ]

    private static let metadataPrefixes = [
        "style",
        "platform",
        "length",
        "lengthlevel",
        "emojilevel",
        "emoji",
        "scene"
    ]

    func sanitizedText(from rawText: String) -> String? {
        let normalizedLines = rawText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let keptLines = normalizedLines.filter { !isMetadataLine($0) }
        let text = keptLines
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard hasMeaningfulCaptionText(text) else {
            return nil
        }

        return text
    }

    func containsMetadataLeak(_ text: String) -> Bool {
        text
            .components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .contains { isMetadataLine($0) }
    }

    private func isMetadataLine(_ line: String) -> Bool {
        let normalized = normalizedMetadataToken(line)
        guard !normalized.isEmpty else {
            return true
        }

        if Self.metadataTokens.contains(normalized) {
            return true
        }

        for prefix in Self.metadataPrefixes {
            if normalized.hasPrefix("\(prefix):") || normalized.hasPrefix("\(prefix)=") {
                let value = normalized
                    .dropFirst(prefix.count + 1)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return Self.metadataTokens.contains(String(value))
            }
        }

        return false
    }

    private func hasMeaningfulCaptionText(_ text: String) -> Bool {
        let stripped = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard stripped.count >= 2 else {
            return false
        }

        let lines = stripped
            .components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            return false
        }

        return lines.contains { !isMetadataLine($0) }
    }

    private func normalizedMetadataToken(_ text: String) -> String {
        text
            .lowercased()
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"'`，。,.[]{}()")))
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
    }
}
