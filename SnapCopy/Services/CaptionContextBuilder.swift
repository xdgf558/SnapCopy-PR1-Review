import Foundation

struct CaptionContextBuilder {
    func build(context: CaptionGenerationContext, preference: UserPreference) -> CaptionContextPayload {
        let analysis = context.analysisResult
        let imageFocus = makeImageFocus(analysis: analysis, context: context)
        let styleSignals = sanitizedStyleSignals(preference: preference)

        return CaptionContextPayload(
            image: CaptionImageContextPayload(
                sceneTags: context.sceneTags,
                primaryScene: context.primaryScene.rawValue,
                captionFocus: imageFocus.captionFocus,
                mustMentionCues: imageFocus.mustMentionCues,
                relationshipCues: imageFocus.relationshipCues,
                semanticSummary: analysis?.semanticSummary.promptSummary,
                subjectCues: analysis?.semanticSummary.subjectCues ?? [],
                objectCues: analysis?.semanticSummary.objectCues ?? [],
                actionCues: analysis?.semanticSummary.actionCues ?? [],
                atmosphereCues: analysis?.semanticSummary.atmosphereCues ?? [],
                avoidUnsupportedClaims: imageFocus.avoidUnsupportedClaims,
                imageDescription: context.imageDescription,
                visionLabels: analysis?.visionLabels.map { label in
                    CaptionVisionLabelPayload(name: label.name, confidence: rounded(label.confidence))
                } ?? [],
                ocrTexts: analysis?.recognizedTexts.map { text in
                    CaptionOCRPayload(text: text.text, confidence: rounded(text.confidence))
                } ?? [],
                featureFlags: CaptionFeatureFlagsPayload(
                    person: analysis?.featureFlags.hasPerson ?? false,
                    food: analysis?.featureFlags.hasFood ?? false,
                    pet: analysis?.featureFlags.hasPet ?? false,
                    street: analysis?.featureFlags.hasStreet ?? false,
                    building: analysis?.featureFlags.hasBuilding ?? false,
                    sky: analysis?.featureFlags.hasSky ?? false,
                    plant: analysis?.featureFlags.hasPlant ?? false
                ),
                resolvedScene: CaptionResolvedScenePayload(
                    scene: analysis?.sceneResolution.scene.rawValue ?? "unknown",
                    subScene: analysis?.sceneResolution.subScene,
                    confidence: rounded(analysis?.sceneResolution.confidence ?? 0),
                    signals: analysis?.sceneResolution.signals ?? []
                ),
                visualTraits: analysis?.visualTraits.promptSummary
            ),
            generation: CaptionGenerationPayload(
                outputLanguage: preference.preferredCaptionLanguage.rawValue,
                platform: preference.preferredPlatforms.first?.rawValue ?? SocialPlatform.general.rawValue,
                platformGuidance: (preference.preferredPlatforms.first ?? .general).promptGuidance,
                lengthLevel: preference.preferredLengthLevel.rawValue,
                lengthGuidance: preference.preferredLengthLevel.promptGuidance,
                preferredStyles: styleSignals.preferredStyles,
                avoidStyles: styleSignals.avoidStyles,
                stylePreferenceWarning: styleSignals.warning,
                likedPhrases: Array(preference.textPreference.likedPhrases.prefix(6)),
                avoidPhrases: preference.dislikedPhrasesForPrompt,
                sentenceShape: preference.textPreference.sentenceShapePrompt,
                emojiPreference: preference.textPreference.emojiPrompt,
                punctuationPreference: preference.textPreference.punctuationPrompt
            )
        )
    }

    private func rounded(_ value: Double) -> Double {
        (value * 1000).rounded() / 1000
    }

    private func makeImageFocus(analysis: ImageAnalysisResult?, context: CaptionGenerationContext) -> CaptionImageFocusPayload {
        guard let analysis else {
            return CaptionImageFocusPayload(
                captionFocus: context.sceneTags.isEmpty ? nil : "Photo scene: \(context.promptSceneTags)",
                mustMentionCues: [],
                relationshipCues: [],
                avoidUnsupportedClaims: generalUnsupportedClaimRules
            )
        }

        let labels = analysis.visionLabels
            .sorted { $0.confidence > $1.confidence }
            .map { $0.name.lowercased() }
        let labelText = (labels + analysis.detectedTexts.map { $0.lowercased() }).joined(separator: " ")
        let hasPet = contains(labelText, petCueKeywords)
        let hasFood = contains(labelText, foodCueKeywords) || analysis.featureFlags.hasFood
        let hasDining = contains(labelText, diningCueKeywords)
        let coreCues = prioritizedCues(from: labels, featureFlags: analysis.featureFlags, visualTraits: analysis.visualTraits)
        let semanticSummary = analysis.semanticSummary
        var avoidUnsupportedClaims = (generalUnsupportedClaimRules + semanticSummary.cautionRules).uniqued()

        if hasDining, !contains(labelText, specificFoodKeywords) {
            avoidUnsupportedClaims.append("Tableware or a plate is not enough evidence for a specific dish. Say food, meal, plate, or table scene instead of steak, beef, dessert, or a named cuisine.")
        }

        if semanticSummary.hasUsefulContext {
            let semanticCues = (semanticSummary.groundingCues + coreCues)
                .uniqued()
                .prefix(8)
                .map { $0 }
            let semanticRelationships = (semanticSummary.relationshipCues + semanticSummary.actionCues)
                .uniqued()
                .prefix(8)
                .map { $0 }

            return CaptionImageFocusPayload(
                captionFocus: semanticSummary.captionFocus,
                mustMentionCues: semanticCues,
                relationshipCues: semanticRelationships,
                avoidUnsupportedClaims: avoidUnsupportedClaims
            )
        }

        if hasPet, hasFood || hasDining {
            let petCue = firstMatchingCue(in: labels, keywords: ["cat", "dog", "feline", "canine", "pet", "animal"]) ?? "pet"
            let diningCues = firstMatchingCues(
                in: labels,
                keywords: ["plate", "tableware", "utensil", "fork", "knife", "spoon", "bowl", "dish", "food", "meal", "table"],
                limit: 4
            )
            let diningCueText = diningCues.isEmpty ? "food/tableware details" : diningCues.joined(separator: ", ")
            let mustMentionCues = ([petCue] + diningCues + coreCues)
                .uniqued()
                .prefix(7)
                .map { $0 }

            return CaptionImageFocusPayload(
                captionFocus: "A \(petCue) in a dining/table scene with \(diningCueText).",
                mustMentionCues: mustMentionCues,
                relationshipCues: [
                    "pet + dining/tableware",
                    "\(petCue) with \(diningCueText)"
                ],
                avoidUnsupportedClaims: avoidUnsupportedClaims
            )
        }

        let focus = coreCues.isEmpty
            ? "Photo scene: \(context.promptSceneTags)"
            : "Photo grounded in these visible cues: \(coreCues.joined(separator: ", "))."

        return CaptionImageFocusPayload(
            captionFocus: focus,
            mustMentionCues: coreCues,
            relationshipCues: [],
            avoidUnsupportedClaims: avoidUnsupportedClaims
        )
    }

    private func sanitizedStyleSignals(preference: UserPreference) -> CaptionStylePromptSignals {
        let preferredStyles = preference.likedStylesForPrompt
        let preferredSet = Set(preferredStyles)
        let rawAvoidStyles = preference.dislikedStylesForPrompt.filter { !preferredSet.contains($0) }
        let allStyles = Set(CaptionStyle.allCases.map(\.rawValue))
        let avoidedSet = Set(rawAvoidStyles)
        let remainingStyleCount = allStyles.subtracting(avoidedSet).count
        let hasOverbroadAvoidance = rawAvoidStyles.count >= max(4, CaptionStyle.allCases.count - 1) || remainingStyleCount <= 1

        if hasOverbroadAvoidance {
            return CaptionStylePromptSignals(
                preferredStyles: preferredStyles,
                avoidStyles: [],
                warning: "avoidStyles were ignored because they covered nearly all writing styles. Prioritize grounded variety and user-liked phrases instead."
            )
        }

        return CaptionStylePromptSignals(
            preferredStyles: preferredStyles,
            avoidStyles: rawAvoidStyles,
            warning: nil
        )
    }

    private func prioritizedCues(
        from labels: [String],
        featureFlags: ImageFeatureFlags,
        visualTraits: ImageVisualTraits
    ) -> [String] {
        let labelCues = priorityCueKeywords.compactMap { keyword in
            labels.first { label in
                label.contains(keyword)
            }
        }

        var cues = labelCues.uniqued()

        if featureFlags.hasPet, !contains(cues.joined(separator: " "), petCueKeywords) {
            cues.append("pet")
        }

        if featureFlags.hasFood, !contains(cues.joined(separator: " "), foodCueKeywords + diningCueKeywords) {
            cues.append("food/table scene")
        }

        if visualTraits.colorTemperature == .warm {
            cues.append("warm light")
        }

        if visualTraits.brightness == .dim || visualTraits.brightness == .dark {
            cues.append("low light")
        }

        return cues.uniqued().prefix(8).map { $0 }
    }

    private func firstMatchingCue(in labels: [String], keywords: [String]) -> String? {
        firstMatchingCues(in: labels, keywords: keywords, limit: 1).first
    }

    private func firstMatchingCues(in labels: [String], keywords: [String], limit: Int) -> [String] {
        keywords.compactMap { keyword in
            labels.first { label in
                label.contains(keyword)
            }
        }
        .uniqued()
        .prefix(limit)
        .map { $0 }
    }

    private func contains(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { keyword in
            text.contains(keyword.lowercased())
        }
    }

    private var generalUnsupportedClaimRules: [String] {
        [
            "Do not claim eye color, breed, exact food type, brand, place, text, or emotion unless it is explicitly supported by visionLabels or OCR.",
            "Do not turn colors from visualTraits into object facts. Warm, red, or orange may describe atmosphere only."
        ]
    }

    private var petCueKeywords: [String] {
        ["cat", "dog", "feline", "canine", "pet", "animal", "puppy", "kitten"]
    }

    private var foodCueKeywords: [String] {
        ["food", "meal", "dish", "restaurant", "cuisine", "dessert", "cake", "breakfast", "brunch", "steak", "meat", "beef"]
    }

    private var diningCueKeywords: [String] {
        ["tableware", "utensil", "plate", "bowl", "fork", "knife", "spoon", "table", "dining"]
    }

    private var specificFoodKeywords: [String] {
        ["steak", "meat", "beef", "dessert", "cake", "bread", "egg", "coffee", "latte", "pancake", "croissant"]
    }

    private var priorityCueKeywords: [String] {
        [
            "cat", "dog", "feline", "canine", "pet", "animal",
            "person", "people", "face", "outfit", "clothing",
            "plate", "tableware", "utensil", "fork", "knife", "spoon", "bowl", "dish", "food", "meal",
            "coffee", "cup", "mug", "table",
            "laptop", "computer", "keyboard", "desk", "notebook",
            "road", "street", "building", "sky", "plant", "tree", "flower",
            "sunset", "beach", "mountain", "ocean", "gym", "yoga"
        ]
    }
}

private struct CaptionImageFocusPayload {
    let captionFocus: String?
    let mustMentionCues: [String]
    let relationshipCues: [String]
    let avoidUnsupportedClaims: [String]
}

private struct CaptionStylePromptSignals {
    let preferredStyles: [String]
    let avoidStyles: [String]
    let warning: String?
}

struct CaptionContextPayload: Codable, Equatable {
    let image: CaptionImageContextPayload
    let generation: CaptionGenerationPayload

    var prettyPrintedJSON: String {
        jsonString(outputFormatting: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    }

    var compactJSON: String {
        jsonString(outputFormatting: [.sortedKeys, .withoutEscapingSlashes])
    }

    private func jsonString(outputFormatting: JSONEncoder.OutputFormatting) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = outputFormatting

        guard let data = try? encoder.encode(self),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }

        return json
    }
}

struct CaptionImageContextPayload: Codable, Equatable {
    let sceneTags: [String]
    let primaryScene: String
    let captionFocus: String?
    let mustMentionCues: [String]
    let relationshipCues: [String]
    let semanticSummary: String?
    let subjectCues: [String]
    let objectCues: [String]
    let actionCues: [String]
    let atmosphereCues: [String]
    let avoidUnsupportedClaims: [String]
    let imageDescription: String?
    let visionLabels: [CaptionVisionLabelPayload]
    let ocrTexts: [CaptionOCRPayload]
    let featureFlags: CaptionFeatureFlagsPayload
    let resolvedScene: CaptionResolvedScenePayload
    let visualTraits: String?
}

struct CaptionVisionLabelPayload: Codable, Equatable {
    let name: String
    let confidence: Double
}

struct CaptionOCRPayload: Codable, Equatable {
    let text: String
    let confidence: Double
}

struct CaptionFeatureFlagsPayload: Codable, Equatable {
    let person: Bool
    let food: Bool
    let pet: Bool
    let street: Bool
    let building: Bool
    let sky: Bool
    let plant: Bool
}

struct CaptionResolvedScenePayload: Codable, Equatable {
    let scene: String
    let subScene: String?
    let confidence: Double
    let signals: [String]
}

struct CaptionGenerationPayload: Codable, Equatable {
    let outputLanguage: String
    let platform: String
    let platformGuidance: String
    let lengthLevel: String
    let lengthGuidance: String
    let preferredStyles: [String]
    let avoidStyles: [String]
    let stylePreferenceWarning: String?
    let likedPhrases: [String]
    let avoidPhrases: [String]
    let sentenceShape: String?
    let emojiPreference: String?
    let punctuationPreference: String?
}

private extension Array where Element == String {
    func uniqued() -> [String] {
        var seen: Set<String> = []

        return filter { item in
            let normalized = item
                .lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !normalized.isEmpty, !seen.contains(normalized) else {
                return false
            }

            seen.insert(normalized)
            return true
        }
    }
}
