import CoreML
import UIKit
import Vision

protocol CustomSceneClassifier {
    func classify(_ image: UIImage) async -> CustomSceneClassificationResult
}

struct CoreMLSceneClassifier: CustomSceneClassifier {
    private let model: MLModel?
    private let isMockEnabled: Bool

    init(
        model: MLModel? = nil,
        modelResourceName: String = "SnapCopySceneClassifier",
        bundle: Bundle = .main,
        isMockEnabled: Bool = false
    ) {
        self.model = model ?? Self.loadBundledModel(named: modelResourceName, in: bundle)
        self.isMockEnabled = isMockEnabled
    }

    func classify(_ image: UIImage) async -> CustomSceneClassificationResult {
        let startedAt = Date()

        guard let model else {
            if isMockEnabled {
                return CustomSceneClassificationResult(
                    status: .mock,
                    predictions: [
                        ScenePrediction(
                            scene: .unknown,
                            confidence: 0.1,
                            source: .customModel,
                            explanation: "Mock placeholder. Replace with a Core ML scene classifier output."
                        )
                    ],
                    latencyMs: elapsedMs(since: startedAt),
                    explanation: "Mock custom classifier is enabled, but no real Core ML model is bundled."
                )
            }

            return CustomSceneClassificationResult(
                status: .disabled,
                predictions: [],
                latencyMs: elapsedMs(since: startedAt),
                explanation: "Custom Core ML classifier disabled because no scene model is bundled."
            )
        }

        guard let cgImage = image.cgImage else {
            return CustomSceneClassificationResult(
                status: .available,
                predictions: [],
                latencyMs: elapsedMs(since: startedAt),
                explanation: "Core ML model is loaded, but the image could not be converted to CGImage."
            )
        }

        do {
            let visionModel = try VNCoreMLModel(for: model)
            let request = VNCoreMLRequest(model: visionModel)
            request.imageCropAndScaleOption = .centerCrop
            let handler = VNImageRequestHandler(
                cgImage: cgImage,
                orientation: CGImagePropertyOrientation(image.imageOrientation),
                options: [:]
            )
            try handler.perform([request])
            let predictions = (request.results as? [VNClassificationObservation] ?? [])
                .compactMap { observation -> ScenePrediction? in
                    guard let scene = SceneType(rawValue: observation.identifier) else {
                        return nil
                    }

                    return ScenePrediction(
                        scene: scene,
                        confidence: Double(observation.confidence),
                        source: .customModel,
                        explanation: "Core ML label '\(observation.identifier)'"
                    )
                }
                .prefix(3)
                .map { $0 }

            return CustomSceneClassificationResult(
                status: .available,
                predictions: predictions,
                latencyMs: elapsedMs(since: startedAt),
                explanation: predictions.isEmpty
                ? "Core ML model is loaded, but it did not return SnapCopy scene labels."
                : "Core ML model loaded from app bundle."
            )
        } catch {
            return CustomSceneClassificationResult(
                status: .available,
                predictions: [],
                latencyMs: elapsedMs(since: startedAt),
                explanation: "Core ML model loaded but prediction failed: \(error.localizedDescription)"
            )
        }
    }

    private func elapsedMs(since startedAt: Date) -> Double {
        Date().timeIntervalSince(startedAt) * 1000
    }

    private static func loadBundledModel(named modelResourceName: String, in bundle: Bundle) -> MLModel? {
        guard let modelURL = bundle.url(forResource: modelResourceName, withExtension: "mlmodelc") else {
            return nil
        }

        return try? MLModel(contentsOf: modelURL)
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
