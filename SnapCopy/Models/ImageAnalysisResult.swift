import Foundation

struct ImageAnalysisResult: Equatable {
    let visionLabels: [VisionImageLabel]
    let recognizedTexts: [RecognizedTextObservation]
    let visualTraits: ImageVisualTraits
    let featureFlags: ImageFeatureFlags
    let sceneResolution: SceneResolution
    let semanticSummary: ImageSemanticSummary
    let customSceneClassification: CustomSceneClassificationResult
    let analysisLatencyMs: Double

    init(
        visionLabels: [VisionImageLabel],
        recognizedTexts: [RecognizedTextObservation],
        visualTraits: ImageVisualTraits,
        featureFlags: ImageFeatureFlags,
        sceneResolution: SceneResolution,
        semanticSummary: ImageSemanticSummary = .empty,
        customSceneClassification: CustomSceneClassificationResult = .disabled,
        analysisLatencyMs: Double = 0
    ) {
        self.visionLabels = visionLabels
        self.recognizedTexts = recognizedTexts
        self.visualTraits = visualTraits
        self.featureFlags = featureFlags
        self.sceneResolution = sceneResolution
        self.semanticSummary = semanticSummary
        self.customSceneClassification = customSceneClassification
        self.analysisLatencyMs = analysisLatencyMs
    }

    static let empty = ImageAnalysisResult(
        visionLabels: [],
        recognizedTexts: [],
        visualTraits: .empty,
        featureFlags: .empty,
        sceneResolution: .unknown,
        semanticSummary: .empty,
        customSceneClassification: .disabled,
        analysisLatencyMs: 0
    )

    var hasUsefulContext: Bool {
        !visionLabels.isEmpty ||
        !recognizedTexts.isEmpty ||
        visualTraits.hasUsefulContext ||
        sceneResolution.scene != .unknown ||
        semanticSummary.hasUsefulContext ||
        !customSceneClassification.predictions.isEmpty
    }

    var detectedLabels: [ImageUnderstandingLabel] {
        visionLabels.map { label in
            ImageUnderstandingLabel(name: label.name, confidence: label.confidence)
        }
    }

    var detectedTexts: [String] {
        recognizedTexts.map(\.text)
    }

    var sceneTags: [String] {
        var tags: [String] = []

        if sceneResolution.scene != .unknown {
            tags.append(sceneResolution.scene.rawValue)
        }

        if let subScene = sceneResolution.subScene, !subScene.isEmpty {
            tags.append(subScene)
        }

        tags.append(contentsOf: ImageSceneMapper.sceneTags(from: visionLabels.map(\.name) + detectedTexts))

        return tags.uniqued().prefix(8).map { $0 }
    }

    var understandingResult: ImageUnderstandingResult {
        ImageUnderstandingResult(
            sceneTags: sceneTags,
            detectedLabels: detectedLabels,
            detectedTexts: detectedTexts,
            visualTraits: visualTraits
        )
    }

    var promptDescription: String? {
        var parts: [String] = []

        if let promptDescription = understandingResult.promptDescription {
            parts.append(promptDescription)
        }

        if let semanticPromptSummary = semanticSummary.promptSummary {
            parts.append(semanticPromptSummary)
        }

        guard !parts.isEmpty else {
            return nil
        }

        return parts.joined(separator: "\n")
    }
}

struct VisionImageLabel: Equatable {
    let name: String
    let confidence: Double
}

struct RecognizedTextObservation: Equatable {
    let text: String
    let confidence: Double
}

struct ImageFeatureFlags: Equatable {
    let hasPerson: Bool
    let hasFood: Bool
    let hasPet: Bool
    let hasStreet: Bool
    let hasBuilding: Bool
    let hasSky: Bool
    let hasPlant: Bool

    static let empty = ImageFeatureFlags(
        hasPerson: false,
        hasFood: false,
        hasPet: false,
        hasStreet: false,
        hasBuilding: false,
        hasSky: false,
        hasPlant: false
    )
}

enum ProductScene: String, Codable, CaseIterable, Identifiable {
    case breakfast
    case cafe
    case walking
    case street
    case travel
    case pet
    case outfit
    case fitness
    case sunset
    case home
    case work
    case food
    case unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .breakfast:
            "早餐"
        case .cafe:
            "咖啡馆"
        case .walking:
            "散步"
        case .street:
            "街景"
        case .travel:
            "旅行"
        case .pet:
            "宠物"
        case .outfit:
            "穿搭"
        case .fitness:
            "健身"
        case .sunset:
            "日落"
        case .home:
            "室内生活"
        case .work:
            "工作"
        case .food:
            "美食"
        case .unknown:
            "未知"
        }
    }
}

struct SceneResolution: Equatable {
    let scene: ProductScene
    let subScene: String?
    let confidence: Double
    let signals: [String]
    let topCandidates: [ScenePrediction]
    let fusionExplanation: String

    init(
        scene: ProductScene,
        subScene: String?,
        confidence: Double,
        signals: [String],
        topCandidates: [ScenePrediction] = [],
        fusionExplanation: String = ""
    ) {
        self.scene = scene
        self.subScene = subScene
        self.confidence = confidence
        self.signals = signals
        self.topCandidates = topCandidates
        self.fusionExplanation = fusionExplanation
    }

    static let unknown = SceneResolution(
        scene: .unknown,
        subScene: nil,
        confidence: 0,
        signals: [],
        topCandidates: [],
        fusionExplanation: "No scene resolved."
    )
}

struct ImageSemanticSummary: Equatable {
    let captionFocus: String?
    let subjectCues: [String]
    let objectCues: [String]
    let actionCues: [String]
    let relationshipCues: [String]
    let atmosphereCues: [String]
    let cautionRules: [String]

    static let empty = ImageSemanticSummary(
        captionFocus: nil,
        subjectCues: [],
        objectCues: [],
        actionCues: [],
        relationshipCues: [],
        atmosphereCues: [],
        cautionRules: []
    )

    var hasUsefulContext: Bool {
        captionFocus != nil ||
        !subjectCues.isEmpty ||
        !objectCues.isEmpty ||
        !actionCues.isEmpty ||
        !relationshipCues.isEmpty ||
        !atmosphereCues.isEmpty
    }

    var groundingCues: [String] {
        (subjectCues + objectCues + atmosphereCues).uniqued()
    }

    var promptSummary: String? {
        guard hasUsefulContext else {
            return nil
        }

        var parts: [String] = []

        if let captionFocus {
            parts.append("Semantic focus: \(captionFocus)")
        }

        if !subjectCues.isEmpty {
            parts.append("Subjects: \(subjectCues.joined(separator: ", "))")
        }

        if !objectCues.isEmpty {
            parts.append("Objects: \(objectCues.joined(separator: ", "))")
        }

        if !actionCues.isEmpty {
            parts.append("Possible actions: \(actionCues.joined(separator: ", "))")
        }

        if !relationshipCues.isEmpty {
            parts.append("Object relationships: \(relationshipCues.joined(separator: ", "))")
        }

        if !atmosphereCues.isEmpty {
            parts.append("Atmosphere: \(atmosphereCues.joined(separator: ", "))")
        }

        return parts.joined(separator: "\n")
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
