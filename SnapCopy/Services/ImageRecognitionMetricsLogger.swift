import Foundation
import UIKit

protocol SceneCorrectionHistoryProviding {
    func recentCorrectionPredictions() -> [ScenePrediction]
}

final class SceneCorrectionHistoryStore: SceneCorrectionHistoryProviding {
    private let defaults: UserDefaults
    private let storageKey: String
    private let maxRecords: Int

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "snapcopy.sceneCorrectionHistory",
        maxRecords: Int = 80
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.maxRecords = maxRecords
    }

    func record(predictedScene: SceneType, selectedScene: SceneType) {
        guard selectedScene != .unknown, selectedScene != predictedScene else {
            return
        }

        var records = loadRecords()
        records.insert(
            SceneCorrectionRecord(
                predictedScene: predictedScene,
                selectedScene: selectedScene,
                createdAt: Date()
            ),
            at: 0
        )
        records = Array(records.prefix(maxRecords))
        save(records)
    }

    func recentCorrectionPredictions() -> [ScenePrediction] {
        let grouped = Dictionary(grouping: loadRecords(), by: \.selectedScene)

        return grouped.map { scene, records in
            let confidence = min(0.9, 0.42 + Double(records.count) * 0.06)
            return ScenePrediction(
                scene: scene,
                confidence: confidence,
                source: .userCorrection,
                explanation: "Recent manual corrections selected \(scene.rawValue) \(records.count) time(s)."
            )
        }
        .sorted { $0.confidence > $1.confidence }
        .prefix(5)
        .map { $0 }
    }

    private func loadRecords() -> [SceneCorrectionRecord] {
        guard let data = defaults.data(forKey: storageKey),
              let records = try? JSONDecoder().decode([SceneCorrectionRecord].self, from: data) else {
            return []
        }

        return records
    }

    private func save(_ records: [SceneCorrectionRecord]) {
        guard let data = try? JSONEncoder().encode(records) else {
            return
        }

        defaults.set(data, forKey: storageKey)
    }
}

final class ImageRecognitionMetricsLogger {
    private let defaults: UserDefaults
    private let storageKey: String
    private let maxRecords: Int

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "snapcopy.imageRecognitionMetrics.debug",
        maxRecords: Int = 300
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.maxRecords = maxRecords
    }

    func recordPrediction(result: ImageAnalysisResult, imageSize: CGSize) {
        append(
            ImageRecognitionMetricRecord(
                predictedScene: SceneType(productScene: result.sceneResolution.scene),
                top3Scenes: result.sceneResolution.topCandidates.map(\.scene),
                userSelectedScene: nil,
                wasUserCorrectionNeeded: result.sceneResolution.confidence < 0.75,
                captionRating: nil,
                modelLatencyMs: result.analysisLatencyMs,
                imageSize: imageSizeText(imageSize)
            )
        )
    }

    func recordUserCorrection(result: ImageAnalysisResult, selectedScene: ProductScene, imageSize: CGSize) {
        append(
            ImageRecognitionMetricRecord(
                predictedScene: SceneType(productScene: result.sceneResolution.scene),
                top3Scenes: result.sceneResolution.topCandidates.map(\.scene),
                userSelectedScene: SceneType(productScene: selectedScene),
                wasUserCorrectionNeeded: true,
                captionRating: nil,
                modelLatencyMs: result.analysisLatencyMs,
                imageSize: imageSizeText(imageSize)
            )
        )
    }

    func recordCaptionRating(result: ImageAnalysisResult?, rating: Int, imageSize: CGSize?) {
        guard let result else {
            return
        }

        append(
            ImageRecognitionMetricRecord(
                predictedScene: SceneType(productScene: result.sceneResolution.scene),
                top3Scenes: result.sceneResolution.topCandidates.map(\.scene),
                userSelectedScene: nil,
                wasUserCorrectionNeeded: result.sceneResolution.confidence < 0.75,
                captionRating: rating,
                modelLatencyMs: result.analysisLatencyMs,
                imageSize: imageSize.map(imageSizeText) ?? "unknown"
            )
        )
    }

    func loadRecords() -> [ImageRecognitionMetricRecord] {
        guard let data = defaults.data(forKey: storageKey),
              let records = try? JSONDecoder().decode([ImageRecognitionMetricRecord].self, from: data) else {
            return []
        }

        return records
    }

    func makeExport(appVersion: String) -> ImageRecognitionMetricsExport {
        let records = loadRecords()

        return ImageRecognitionMetricsExport(
            exportedAt: Date(),
            appVersion: appVersion,
            recordCount: records.count,
            records: records
        )
    }

    func makeExportData(appVersion: String) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        return try? encoder.encode(makeExport(appVersion: appVersion))
    }

    private func append(_ record: ImageRecognitionMetricRecord) {
        var records = loadRecords()
        records.insert(record, at: 0)
        records = Array(records.prefix(maxRecords))

        guard let data = try? JSONEncoder().encode(records) else {
            return
        }

        defaults.set(data, forKey: storageKey)
    }

    private func imageSizeText(_ size: CGSize) -> String {
        "\(Int(size.width.rounded()))x\(Int(size.height.rounded()))"
    }
}

struct ImageRecognitionMetricsExport: Codable, Equatable {
    let schemaVersion: Int
    let exportedAt: Date
    let appVersion: String
    let recordCount: Int
    let records: [ImageRecognitionMetricRecord]

    init(
        schemaVersion: Int = 1,
        exportedAt: Date,
        appVersion: String,
        recordCount: Int,
        records: [ImageRecognitionMetricRecord]
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.appVersion = appVersion
        self.recordCount = recordCount
        self.records = records
    }
}

private struct SceneCorrectionRecord: Codable, Equatable {
    let predictedScene: SceneType
    let selectedScene: SceneType
    let createdAt: Date
}
