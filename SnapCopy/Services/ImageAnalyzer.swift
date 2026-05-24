import ImageIO
import UIKit
import Vision

final class ImageAnalyzer {
    private let customSceneClassifier: CustomSceneClassifier
    private let correctionHistoryProvider: SceneCorrectionHistoryProviding

    init(
        customSceneClassifier: CustomSceneClassifier = CoreMLSceneClassifier(),
        correctionHistoryProvider: SceneCorrectionHistoryProviding = SceneCorrectionHistoryStore()
    ) {
        self.customSceneClassifier = customSceneClassifier
        self.correctionHistoryProvider = correctionHistoryProvider
    }

    func analyze(_ image: UIImage) async -> ImageAnalysisResult {
        let startedAt = Date()
        async let baseAnalysis = Task.detached(priority: .userInitiated) {
            Self.analyzeBase(image)
        }.value
        async let customClassification = customSceneClassifier.classify(image)

        let base = await baseAnalysis
        let customResult = await customClassification
        let correctionPredictions = correctionHistoryProvider.recentCorrectionPredictions()

        return Self.makeResult(
            base: base,
            customClassification: customResult,
            correctionPredictions: correctionPredictions,
            analysisLatencyMs: Date().timeIntervalSince(startedAt) * 1000
        )
    }

    private static func analyzeBase(_ image: UIImage) -> BaseImageAnalysis {
        guard let cgImage = image.cgImage else {
            return .empty
        }

        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let labels = mergedLabels(
            detectedLabels(in: cgImage, orientation: orientation) +
            regionalLabels(in: cgImage)
        )
        let recognizedTexts = recognizedTexts(in: cgImage, orientation: orientation)
        let visualTraits = ImageVisualAnalyzer.visualTraits(from: cgImage, imageSize: image.size)
        let featureFlags = ImageFeatureDetector.flags(labels: labels, texts: recognizedTexts.map(\.text))
        let partialResult = ImageAnalysisResult(
            visionLabels: labels,
            recognizedTexts: recognizedTexts,
            visualTraits: visualTraits,
            featureFlags: featureFlags,
            sceneResolution: .unknown,
            semanticSummary: .empty
        )

        return BaseImageAnalysis(
            labels: labels,
            recognizedTexts: recognizedTexts,
            visualTraits: visualTraits,
            featureFlags: featureFlags,
            partialResult: partialResult
        )
    }

    private static func makeResult(
        base: BaseImageAnalysis,
        customClassification: CustomSceneClassificationResult,
        correctionPredictions: [ScenePrediction],
        analysisLatencyMs: Double
    ) -> ImageAnalysisResult {
        guard !base.isEmpty else {
            return ImageAnalysisResult(
                visionLabels: [],
                recognizedTexts: [],
                visualTraits: .empty,
                featureFlags: .empty,
                sceneResolution: .unknown,
                semanticSummary: .empty,
                customSceneClassification: customClassification,
                analysisLatencyMs: analysisLatencyMs
            )
        }

        let sceneResolution = SceneResolver().resolve(
            labels: base.labels,
            texts: base.recognizedTexts,
            visualTraits: base.visualTraits,
            customPredictions: customClassification.predictions,
            userCorrections: correctionPredictions
        )
        let semanticSummary = ImageSemanticInterpreter.summary(
            labels: base.labels,
            texts: base.recognizedTexts.map(\.text),
            visualTraits: base.visualTraits,
            featureFlags: base.featureFlags,
            sceneResolution: sceneResolution
        )

        return ImageAnalysisResult(
            visionLabels: base.labels,
            recognizedTexts: base.recognizedTexts,
            visualTraits: base.visualTraits,
            featureFlags: base.featureFlags,
            sceneResolution: sceneResolution,
            semanticSummary: semanticSummary,
            customSceneClassification: customClassification,
            analysisLatencyMs: analysisLatencyMs
        )
    }

    private static func detectedLabels(in cgImage: CGImage, orientation: CGImagePropertyOrientation) -> [VisionImageLabel] {
        let request = VNClassifyImageRequest()
        request.usesCPUOnly = false

        do {
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            try handler.perform([request])

            return (request.results ?? [])
                .filter { $0.confidence >= 0.08 }
                .prefix(18)
                .map { observation in
                    VisionImageLabel(name: observation.identifier, confidence: Double(observation.confidence))
                }
        } catch {
            return []
        }
    }

    private static func regionalLabels(in cgImage: CGImage) -> [VisionImageLabel] {
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        guard width > 10, height > 10 else {
            return []
        }

        let cropRects = [
            CGRect(x: width * 0.16, y: height * 0.10, width: width * 0.68, height: height * 0.72),
            CGRect(x: width * 0.14, y: height * 0.42, width: width * 0.72, height: height * 0.46)
        ]

        return cropRects.flatMap { rect -> [VisionImageLabel] in
            guard let croppedImage = cgImage.cropping(to: rect.integral) else {
                return []
            }

            return detectedLabels(in: croppedImage, orientation: .up)
                .map { label in
                    VisionImageLabel(name: label.name, confidence: min(0.98, label.confidence * 0.92))
                }
        }
    }

    private static func mergedLabels(_ labels: [VisionImageLabel]) -> [VisionImageLabel] {
        var bestLabels: [String: VisionImageLabel] = [:]

        for label in labels {
            let normalizedName = label.name.lowercased()
            if let current = bestLabels[normalizedName], current.confidence >= label.confidence {
                continue
            }

            bestLabels[normalizedName] = VisionImageLabel(name: normalizedName, confidence: label.confidence)
        }

        return bestLabels.values
            .sorted { $0.confidence > $1.confidence }
            .prefix(24)
            .map { $0 }
    }

    private static func recognizedTexts(in cgImage: CGImage, orientation: CGImagePropertyOrientation) -> [RecognizedTextObservation] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US", "ja-JP"]

        do {
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            try handler.perform([request])

            var seen: Set<String> = []

            return (request.results ?? [])
                .compactMap { observation -> RecognizedTextObservation? in
                    guard let candidate = observation.topCandidates(1).first else {
                        return nil
                    }

                    let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard candidate.confidence >= 0.35, !text.isEmpty, text.count <= 80 else {
                        return nil
                    }

                    guard !seen.contains(text) else {
                        return nil
                    }

                    seen.insert(text)
                    return RecognizedTextObservation(text: text, confidence: Double(candidate.confidence))
                }
                .prefix(8)
                .map { $0 }
        } catch {
            return []
        }
    }
}

private struct BaseImageAnalysis {
    let labels: [VisionImageLabel]
    let recognizedTexts: [RecognizedTextObservation]
    let visualTraits: ImageVisualTraits
    let featureFlags: ImageFeatureFlags
    let partialResult: ImageAnalysisResult

    static let empty = BaseImageAnalysis(
        labels: [],
        recognizedTexts: [],
        visualTraits: .empty,
        featureFlags: .empty,
        partialResult: .empty
    )

    var isEmpty: Bool {
        labels.isEmpty &&
        recognizedTexts.isEmpty &&
        !visualTraits.hasUsefulContext &&
        featureFlags == .empty
    }
}

enum ImageSemanticInterpreter {
    static func summary(
        labels: [VisionImageLabel],
        texts: [String],
        visualTraits: ImageVisualTraits,
        featureFlags: ImageFeatureFlags,
        sceneResolution: SceneResolution
    ) -> ImageSemanticSummary {
        let labelNames = labels.map { $0.name.lowercased() }
        let combinedText = (labelNames + texts.map { $0.lowercased() }).joined(separator: " ")
        let subjects = subjectCues(from: labelNames, flags: featureFlags)
        let objects = objectCues(from: labelNames, flags: featureFlags)
        let atmosphere = atmosphereCues(from: visualTraits, labelText: combinedText)
        var actions: [String] = []
        var relationships: [String] = []
        var cautionRules: [String] = [
            "Treat semantic actions as soft local inferences from label combinations, not as guaranteed facts.",
            "Do not name a specific dish, breed, exact place, brand, or emotion unless labels or OCR directly support it."
        ]

        let hasPet = featureFlags.hasPet || contains(combinedText, petKeywords)
        let hasFood = featureFlags.hasFood || contains(combinedText, foodKeywords)
        let hasDining = contains(combinedText, diningKeywords)
        let hasUtensil = contains(combinedText, utensilKeywords)
        let hasTable = contains(combinedText, ["table", "desk", "dining", "桌", "餐桌"])
        let hasCoffee = contains(combinedText, ["coffee", "espresso", "latte", "cappuccino", "cup", "mug", "咖啡"])
        let hasWorkObject = contains(combinedText, ["laptop", "computer", "keyboard", "desk", "notebook", "document", "monitor"])
        let hasPerson = featureFlags.hasPerson || contains(combinedText, ["person", "people", "portrait", "face", "human"])
        let hasOutfit = contains(combinedText, ["clothing", "dress", "shoe", "bag", "fashion", "outfit", "mirror"])

        if hasPet, hasFood || hasDining {
            relationships.append("pet + food/tableware")
            actions.append(hasUtensil ? "pet in a human-like dining setup" : "pet interacting with a meal or table setting")

            if hasTable {
                relationships.append("pet at table")
            }

            if !contains(combinedText, specificFoodKeywords) {
                cautionRules.append("For pet dining scenes without specific food labels, say meal, food, plate, or table scene instead of naming steak, beef, dessert, or cuisine.")
            }
        }

        if hasCoffee, hasTable || hasDining {
            relationships.append("coffee or cup + table setting")
            actions.append("quiet cafe/table moment")
        }

        if hasWorkObject {
            relationships.append("desk objects + work context")
            actions.append("working, planning, or focused desk moment")
        }

        if hasPerson, hasOutfit {
            relationships.append("person + clothing/outfit details")
            actions.append("outfit or mirror-check moment")
        }

        if featureFlags.hasStreet, featureFlags.hasBuilding || featureFlags.hasSky {
            relationships.append("street route + city/outdoor context")
            actions.append("walking or moving through an outdoor scene")
        }

        let focus = captionFocus(
            scene: sceneResolution.scene,
            subjects: subjects,
            objects: objects,
            actions: actions,
            relationships: relationships,
            atmosphere: atmosphere
        )

        return ImageSemanticSummary(
            captionFocus: focus,
            subjectCues: subjects,
            objectCues: objects,
            actionCues: actions.uniqued(),
            relationshipCues: relationships.uniqued(),
            atmosphereCues: atmosphere,
            cautionRules: cautionRules.uniqued()
        )
    }

    private static func captionFocus(
        scene: ProductScene,
        subjects: [String],
        objects: [String],
        actions: [String],
        relationships: [String],
        atmosphere: [String]
    ) -> String? {
        if relationships.contains("pet + food/tableware") {
            let subject = subjects.first ?? "pet"
            let tableObjects = objects.filter { object in
                contains(object, foodKeywords + diningKeywords + utensilKeywords)
            }
            let objectText = tableObjects.isEmpty ? "food/tableware" : tableObjects.prefix(4).joined(separator: ", ")
            return "A \(subject) in a dining/table scene with \(objectText); the important angle is the pet-and-meal relationship, not just a generic pet scene."
        }

        if relationships.contains("coffee or cup + table setting") {
            return "A coffee/cup table moment with visible cafe or tabletop details."
        }

        if relationships.contains("desk objects + work context") {
            return "A work desk scene grounded in visible desk objects and focused work context."
        }

        if relationships.contains("person + clothing/outfit details") {
            return "An outfit/person scene grounded in visible clothing and styling details."
        }

        if scene == .sunset, !atmosphere.isEmpty {
            return "An outdoor light moment grounded in \(atmosphere.prefix(3).joined(separator: ", "))."
        }

        let cueText = (subjects + objects + atmosphere).uniqued().prefix(5).joined(separator: ", ")
        return cueText.isEmpty ? nil : "A \(scene.rawValue) scene grounded in \(cueText)."
    }

    private static func subjectCues(from labels: [String], flags: ImageFeatureFlags) -> [String] {
        var cues = firstMatches(
            in: labels,
            keywords: [
                "cat", "dog", "feline", "canine", "puppy", "kitten", "pet", "animal",
                "person", "people", "face", "portrait"
            ],
            limit: 4
        )

        if flags.hasPet, cues.isEmpty {
            cues.append("pet")
        }

        if flags.hasPerson, !contains(cues.joined(separator: " "), ["person", "people", "face"]) {
            cues.append("person")
        }

        return cues.uniqued()
    }

    private static func objectCues(from labels: [String], flags: ImageFeatureFlags) -> [String] {
        var cues = firstMatches(
            in: labels,
            keywords: [
                "plate", "tableware", "utensil", "fork", "knife", "spoon", "bowl", "dish", "food", "meal",
                "steak", "meat", "beef", "coffee", "cup", "mug", "table",
                "laptop", "computer", "keyboard", "desk", "notebook",
                "clothing", "dress", "shoe", "bag",
                "road", "street", "building", "sky", "plant", "tree", "flower"
            ],
            limit: 8
        )

        if flags.hasFood, !contains(cues.joined(separator: " "), foodKeywords + diningKeywords) {
            cues.append("food/table scene")
        }

        if flags.hasStreet, !contains(cues.joined(separator: " "), ["street", "road"]) {
            cues.append("street")
        }

        return cues.uniqued()
    }

    private static func atmosphereCues(from visualTraits: ImageVisualTraits, labelText: String) -> [String] {
        var cues: [String] = []

        if visualTraits.brightness == .dim || visualTraits.brightness == .dark {
            cues.append("low light")
        } else if visualTraits.brightness == .bright {
            cues.append("bright light")
        }

        if visualTraits.colorTemperature == .warm {
            cues.append("warm color temperature")
        } else if visualTraits.colorTemperature == .cool {
            cues.append("cool color temperature")
        }

        if visualTraits.saturation == .vivid {
            cues.append("vivid color")
        } else if visualTraits.saturation == .muted {
            cues.append("muted color")
        }

        if contains(labelText, ["sunset", "sunrise", "dusk", "twilight"]) {
            cues.append("sunset/sunrise light")
        }

        return cues.uniqued()
    }

    private static func firstMatches(in labels: [String], keywords: [String], limit: Int) -> [String] {
        keywords.compactMap { keyword in
            labels.first { label in
                label.contains(keyword)
            }
        }
        .uniqued()
        .prefix(limit)
        .map { $0 }
    }

    private static func contains(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { keyword in
            text.contains(keyword.lowercased())
        }
    }

    private static let petKeywords = ["cat", "dog", "pet", "animal", "puppy", "kitten", "feline", "canine", "猫", "狗"]
    private static let foodKeywords = ["food", "meal", "dish", "restaurant", "cuisine", "dessert", "cake", "breakfast", "brunch", "steak", "meat", "beef", "餐", "饭", "菜", "肉", "牛排"]
    private static let diningKeywords = ["tableware", "plate", "bowl", "table", "dining", "餐具", "盘", "碗", "桌"]
    private static let utensilKeywords = ["utensil", "fork", "knife", "spoon", "叉", "刀", "勺"]
    private static let specificFoodKeywords = ["steak", "meat", "beef", "dessert", "cake", "bread", "egg", "coffee", "latte", "pancake", "croissant"]
}

enum ImageFeatureDetector {
    static func flags(labels: [VisionImageLabel], texts: [String]) -> ImageFeatureFlags {
        let combined = (labels.map(\.name) + texts).joined(separator: " ").lowercased()
        let labelNames = labels.map { $0.name.lowercased() }

        return ImageFeatureFlags(
            hasPerson: hasPersonSignal(in: labelNames),
            hasFood: contains(combined, ["food", "meal", "dish", "plate", "bowl", "tableware", "utensil", "fork", "knife", "restaurant", "breakfast", "coffee", "dessert", "餐", "饭", "菜"]),
            hasPet: contains(combined, ["dog", "cat", "pet", "animal", "puppy", "kitten", "feline", "canine", "猫", "狗"]),
            hasStreet: contains(combined, ["street", "road", "sidewalk", "city", "urban", "traffic", "街", "路"]),
            hasBuilding: contains(combined, ["building", "architecture", "house", "home", "office", "skyline", "楼", "建筑"]),
            hasSky: contains(combined, ["sky", "cloud", "sunset", "sunrise", "dusk", "twilight", "天空", "日落"]),
            hasPlant: contains(combined, ["plant", "tree", "flower", "grass", "leaf", "forest", "garden", "植物", "花", "树"])
        )
    }

    private static func contains(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { keyword in
            text.contains(keyword.lowercased())
        }
    }

    private static func hasPersonSignal(in labelNames: [String]) -> Bool {
        let exactPersonLabels: Set<String> = [
            "person",
            "people",
            "human",
            "face",
            "portrait",
            "selfie",
            "man",
            "woman",
            "boy",
            "girl"
        ]
        let falsePositiveLabels: Set<String> = [
            "dresser",
            "dressing table",
            "furniture",
            "cabinet",
            "wardrobe"
        ]

        return labelNames.contains { label in
            let normalized = label.replacingOccurrences(of: "_", with: " ")

            if falsePositiveLabels.contains(normalized) {
                return false
            }

            if exactPersonLabels.contains(normalized) {
                return true
            }

            let tokens = Set(normalized.split { !$0.isLetter }.map(String.init))
            return !tokens.isDisjoint(with: exactPersonLabels)
        }
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up:
            self = .up
        case .upMirrored:
            self = .upMirrored
        case .down:
            self = .down
        case .downMirrored:
            self = .downMirrored
        case .left:
            self = .left
        case .leftMirrored:
            self = .leftMirrored
        case .right:
            self = .right
        case .rightMirrored:
            self = .rightMirrored
        @unknown default:
            self = .up
        }
    }
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
