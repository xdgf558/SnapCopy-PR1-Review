import Foundation

enum PredictionSource: String, Codable, CaseIterable, Identifiable {
    case vision
    case ocr
    case customModel
    case userCorrection
    case ruleBased

    var id: String { rawValue }
}

struct ScenePrediction: Codable, Equatable, Identifiable {
    let scene: SceneType
    let confidence: Double
    let source: PredictionSource
    let explanation: String

    var id: String {
        "\(source.rawValue)-\(scene.rawValue)-\(Int((confidence * 1000).rounded()))-\(explanation)"
    }

    init(scene: SceneType, confidence: Double, source: PredictionSource, explanation: String = "") {
        self.scene = scene
        self.confidence = min(1, max(0, confidence))
        self.source = source
        self.explanation = explanation
    }
}

struct SceneFusionResult: Equatable {
    let topCandidates: [ScenePrediction]
    let finalScene: SceneType
    let confidence: Double
    let explanation: String

    static let unknown = SceneFusionResult(
        topCandidates: [],
        finalScene: .unknown,
        confidence: 0,
        explanation: "No usable scene signals were available."
    )
}

enum CustomSceneClassifierStatus: String, Codable, Equatable {
    case disabled
    case mock
    case available
}

struct CustomSceneClassificationResult: Equatable {
    let status: CustomSceneClassifierStatus
    let predictions: [ScenePrediction]
    let latencyMs: Double
    let explanation: String

    static let disabled = CustomSceneClassificationResult(
        status: .disabled,
        predictions: [],
        latencyMs: 0,
        explanation: "No Core ML scene model is bundled in this build."
    )
}

struct ImageRecognitionMetricRecord: Codable, Equatable, Identifiable {
    let id: UUID
    let predictedScene: SceneType
    let top3Scenes: [SceneType]
    let userSelectedScene: SceneType?
    let wasUserCorrectionNeeded: Bool
    let captionRating: Int?
    let modelLatencyMs: Double
    let imageSize: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        predictedScene: SceneType,
        top3Scenes: [SceneType],
        userSelectedScene: SceneType?,
        wasUserCorrectionNeeded: Bool,
        captionRating: Int?,
        modelLatencyMs: Double,
        imageSize: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.predictedScene = predictedScene
        self.top3Scenes = top3Scenes
        self.userSelectedScene = userSelectedScene
        self.wasUserCorrectionNeeded = wasUserCorrectionNeeded
        self.captionRating = captionRating
        self.modelLatencyMs = modelLatencyMs
        self.imageSize = imageSize
        self.createdAt = createdAt
    }
}

extension SceneType {
    init(productScene: ProductScene) {
        switch productScene {
        case .breakfast:
            self = .breakfast
        case .cafe:
            self = .cafe
        case .walking:
            self = .walking
        case .street:
            self = .street
        case .travel:
            self = .travel
        case .pet:
            self = .pet
        case .outfit:
            self = .outfit
        case .fitness:
            self = .fitness
        case .sunset:
            self = .sunset
        case .home:
            self = .home
        case .work:
            self = .work
        case .food:
            self = .food
        case .unknown:
            self = .unknown
        }
    }

    var productScene: ProductScene {
        switch self {
        case .breakfast:
            return .breakfast
        case .cafe:
            return .cafe
        case .walking:
            return .walking
        case .street:
            return .street
        case .travel:
            return .travel
        case .pet:
            return .pet
        case .outfit:
            return .outfit
        case .fitness:
            return .fitness
        case .sunset:
            return .sunset
        case .home:
            return .home
        case .work:
            return .work
        case .food:
            return .food
        case .daily:
            return .home
        case .unknown:
            return .unknown
        }
    }
}

extension ProductScene {
    init(sceneType: SceneType) {
        self = sceneType.productScene
    }
}

extension ManualSceneOption {
    var productScene: ProductScene? {
        switch self {
        case .auto:
            return nil
        case .breakfast:
            return .breakfast
        case .coffee:
            return .cafe
        case .walk:
            return .walking
        case .travel:
            return .travel
        case .outfit:
            return .outfit
        case .pet:
            return .pet
        case .workout:
            return .fitness
        case .street:
            return .street
        case .food:
            return .food
        case .work:
            return .work
        case .other:
            return .home
        }
    }
}
