import Foundation

struct CaptionGenerationContext: Equatable {
    let sceneTags: [String]
    let imageDescription: String?
    let source: CaptionGenerationContextSource
    let analysisResult: ImageAnalysisResult?

    static let empty = CaptionGenerationContext(sceneTags: [], imageDescription: nil, source: .none)

    init(
        sceneTags: [String],
        imageDescription: String?,
        source: CaptionGenerationContextSource,
        analysisResult: ImageAnalysisResult? = nil
    ) {
        self.sceneTags = Self.normalized(sceneTags)
        self.imageDescription = imageDescription?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.source = self.sceneTags.isEmpty && self.imageDescription == nil ? .none : source
        self.analysisResult = analysisResult
    }

    init(visionResult: ImageUnderstandingResult?, manualScene: ManualSceneOption) {
        if manualScene != .auto {
            let descriptionParts = [
                "Manual scene: \(manualScene.displayName)",
                visionResult?.promptDescription
            ]
            .compactMap { $0 }

            self.init(
                sceneTags: manualScene.sceneTags,
                imageDescription: descriptionParts.joined(separator: "\n"),
                source: .manual
            )
            return
        }

        guard let visionResult, visionResult.hasUsefulContext else {
            self.init(sceneTags: [], imageDescription: nil, source: .none)
            return
        }

        self.init(
            sceneTags: visionResult.sceneTags,
            imageDescription: visionResult.promptDescription,
            source: .vision
        )
    }

    init(analysisResult: ImageAnalysisResult?, manualScene: ManualSceneOption) {
        if manualScene != .auto {
            let descriptionParts = [
                "Manual scene: \(manualScene.displayName)",
                analysisResult?.promptDescription
            ]
            .compactMap { $0 }

            self.init(
                sceneTags: manualScene.sceneTags,
                imageDescription: descriptionParts.joined(separator: "\n"),
                source: .manual,
                analysisResult: analysisResult
            )
            return
        }

        guard let analysisResult, analysisResult.hasUsefulContext else {
            self.init(sceneTags: [], imageDescription: nil, source: .none)
            return
        }

        self.init(
            sceneTags: analysisResult.sceneTags,
            imageDescription: analysisResult.promptDescription,
            source: .vision,
            analysisResult: analysisResult
        )
    }

    var primaryScene: SceneType {
        if containsAny(["pet", "cat", "dog"]) {
            return .pet
        }

        if containsAny(["travel", "landscape", "beach", "mountain"]) {
            return .travel
        }

        if containsAny(["street", "city", "urban", "walking"]) {
            return .street
        }

        if containsAny(["work", "desk", "office"]) {
            return .work
        }

        if containsAny(["food", "breakfast", "coffee", "meal", "drink", "cafe"]) {
            return .food
        }

        if containsAny(["daily", "walk", "outfit", "workout"]) {
            return .daily
        }

        return .unknown
    }

    var promptSceneTags: String {
        sceneTags.isEmpty ? "unknown" : sceneTags.joined(separator: ", ")
    }

    var hasImageDetails: Bool {
        guard let imageDescription else {
            return false
        }

        return imageDescription.contains("Vision labels:") ||
        imageDescription.contains("Visible text OCR:") ||
        imageDescription.contains("Visual traits:")
    }

    var scenePreferenceLookupTags: [String] {
        var tags = sceneTags

        let primarySceneTag = primaryScene.rawValue
        if primaryScene != .unknown, !tags.contains(primarySceneTag) {
            tags.append(primarySceneTag)
        }

        return Self.normalized(tags)
    }

    private func containsAny(_ candidates: [String]) -> Bool {
        sceneTags.contains { tag in
            candidates.contains(tag)
        }
    }

    private static func normalized(_ tags: [String]) -> [String] {
        var seen: Set<String> = []

        return tags.compactMap { tag in
            let normalizedTag = tag
                .lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: " ", with: "-")

            guard !normalizedTag.isEmpty, !seen.contains(normalizedTag) else {
                return nil
            }

            seen.insert(normalizedTag)
            return normalizedTag
        }
    }
}

enum CaptionGenerationContextSource: Equatable {
    case none
    case vision
    case manual
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
