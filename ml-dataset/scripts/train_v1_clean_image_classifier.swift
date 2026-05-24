#!/usr/bin/env swift
import CreateML
import Foundation

struct SplitCounts {
    let total: Int
    let perClass: [String: Int]
}

enum TrainingError: Error, CustomStringConvertible {
    case missingDirectory(String)
    case emptySplit(String)

    var description: String {
        switch self {
        case .missingDirectory(let path):
            return "Missing directory: \(path)"
        case .emptySplit(let split):
            return "No images found in split: \(split)"
        }
    }
}

let fileManager = FileManager.default
let repoRoot = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let datasetRoot = repoRoot.appendingPathComponent("ml-dataset/v1_clean")
let sourceTrainURL = datasetRoot.appendingPathComponent("train")
let sourceValidationURL = datasetRoot.appendingPathComponent("validation")
let sourceTestURL = datasetRoot.appendingPathComponent("test")
let exportsURL = repoRoot.appendingPathComponent("ml-dataset/exports", isDirectory: true)
let reportURL = repoRoot.appendingPathComponent("ml-dataset/reports/v1_clean_training_report.md")
let outputModelURL = exportsURL.appendingPathComponent("CaptionSceneClassifier_v1_clean.mlmodel")
let stagingRoot = URL(fileURLWithPath: "/private/tmp/SnapCopyCreateML-\(UUID().uuidString)", isDirectory: true)
let stagedDatasetRoot = stagingRoot.appendingPathComponent("v1_clean", isDirectory: true)
let trainURL = stagedDatasetRoot.appendingPathComponent("train")
let validationURL = stagedDatasetRoot.appendingPathComponent("validation")
let testURL = stagedDatasetRoot.appendingPathComponent("test")
let stagedModelURL = stagingRoot.appendingPathComponent("CaptionSceneClassifier_v1_clean.mlmodel")

func labeledImageURLs(in splitURL: URL) throws -> [String: [URL]] {
    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: splitURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
        throw TrainingError.missingDirectory(splitURL.path)
    }

    let classURLs = try fileManager.contentsOfDirectory(
        at: splitURL,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
    )

    var filesByLabel: [String: [URL]] = [:]
    for classURL in classURLs {
        let values = try classURL.resourceValues(forKeys: [.isDirectoryKey])
        guard values.isDirectory == true else { continue }

        let files = try fileManager.contentsOfDirectory(
            at: classURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        let imageFiles = files.filter { url in
            ["jpg", "jpeg", "png", "heic"].contains(url.pathExtension.lowercased())
        }
        filesByLabel[classURL.lastPathComponent] = imageFiles.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    return filesByLabel
}

func imageCount(in splitURL: URL) throws -> SplitCounts {
    let filesByLabel = try labeledImageURLs(in: splitURL)
    let perClass = filesByLabel.mapValues(\.count)
    let total = perClass.values.reduce(0, +)
    return SplitCounts(total: total, perClass: perClass)
}

func accuracy(from metrics: MLClassifierMetrics) -> Double {
    max(0.0, min(1.0, 1.0 - metrics.classificationError))
}

func percent(_ value: Double) -> String {
    String(format: "%.2f%%", value * 100)
}

func markdownTable(for title: String, counts: SplitCounts, scenes: [String]) -> [String] {
    var lines: [String] = [
        "## \(title)",
        "",
        "| Scene | Count |",
        "|---|---:|"
    ]
    for scene in scenes {
        lines.append("| \(scene) | \(counts.perClass[scene, default: 0]) |")
    }
    lines.append("| **Total** | **\(counts.total)** |")
    lines.append("")
    return lines
}

let scenes = [
    "breakfast",
    "cafe",
    "walking",
    "street",
    "travel",
    "pet",
    "outfit",
    "fitness",
    "sunset",
    "home",
    "work",
    "food",
    "unknown"
]

do {
    try fileManager.createDirectory(at: exportsURL, withIntermediateDirectories: true)
    try fileManager.createDirectory(at: reportURL.deletingLastPathComponent(), withIntermediateDirectories: true)

    let trainCounts = try imageCount(in: sourceTrainURL)
    let validationCounts = try imageCount(in: sourceValidationURL)
    let testCounts = try imageCount(in: sourceTestURL)

    guard trainCounts.total > 0 else { throw TrainingError.emptySplit("train") }
    guard validationCounts.total > 0 else { throw TrainingError.emptySplit("validation") }
    guard testCounts.total > 0 else { throw TrainingError.emptySplit("test") }

    try fileManager.createDirectory(at: stagingRoot, withIntermediateDirectories: true)
    try fileManager.copyItem(at: datasetRoot, to: stagedDatasetRoot)

    print("Training images: \(trainCounts.total)")
    print("Validation images: \(validationCounts.total)")
    print("Test images: \(testCounts.total)")
    print("Staged dataset: \(stagedDatasetRoot.path)")
    print("Training Create ML image classifier...")

    let trainingData = MLImageClassifier.DataSource.filesByLabel(try labeledImageURLs(in: trainURL))
    let validationData = MLImageClassifier.DataSource.filesByLabel(try labeledImageURLs(in: validationURL))
    let testData = MLImageClassifier.DataSource.filesByLabel(try labeledImageURLs(in: testURL))
    let parameters = MLImageClassifier.ModelParameters(
        featureExtractor: .scenePrint(revision: 1),
        validationData: validationData,
        maxIterations: 25,
        augmentationOptions: []
    )

    let startedAt = Date()
    let classifier = try MLImageClassifier(trainingData: trainingData, parameters: parameters)
    let elapsed = Date().timeIntervalSince(startedAt)

    let trainingMetrics = classifier.trainingMetrics
    let validationMetrics = classifier.validationMetrics
    let testMetrics = classifier.evaluation(on: testData)

    let metadata = MLModelMetadata(
        author: "Station Cat",
        shortDescription: "SnapCopy cleaned v1 local scene classifier trained with Create ML.",
        version: "v1_clean_2026-05-19",
        additional: [
            "dataset": "ml-dataset/v1_clean",
            "train_image_count": "\(trainCounts.total)",
            "validation_image_count": "\(validationCounts.total)",
            "test_image_count": "\(testCounts.total)",
            "maxIterations": "25",
            "featureExtractor": "scenePrint(revision: 1)",
            "augmentation": "none"
        ]
    )
    try classifier.write(to: stagedModelURL, metadata: metadata)
    if fileManager.fileExists(atPath: outputModelURL.path) {
        try fileManager.removeItem(at: outputModelURL)
    }
    try fileManager.copyItem(at: stagedModelURL, to: outputModelURL)

    var lines: [String] = [
        "# v1_clean Create ML Training Report",
        "",
        "- Model: `CaptionSceneClassifier_v1_clean.mlmodel`",
        "- Dataset: `ml-dataset/v1_clean`",
        "- Tool: Apple Create ML `MLImageClassifier`",
        "- Feature extractor: `scenePrint(revision: 1)`",
        "- Max iterations: 25",
        "- Augmentation: none",
        "- Training time: \(String(format: "%.1f", elapsed)) seconds",
        "- Output: `ml-dataset/exports/CaptionSceneClassifier_v1_clean.mlmodel`",
        "",
        "## Accuracy",
        "",
        "| Split | Classification Error | Accuracy |",
        "|---|---:|---:|",
        "| Training | \(String(format: "%.4f", trainingMetrics.classificationError)) | \(percent(accuracy(from: trainingMetrics))) |",
        "| Validation | \(String(format: "%.4f", validationMetrics.classificationError)) | \(percent(accuracy(from: validationMetrics))) |",
        "| Test | \(String(format: "%.4f", testMetrics.classificationError)) | \(percent(accuracy(from: testMetrics))) |",
        "",
        "## Notes",
        "",
        "- This is a small cleaned-v1 baseline, not the final v2 model.",
        "- v1_clean is still imbalanced after removing prompt/screenshot artifacts; use it as a quick sanity model.",
        "- Keep the test split stable for comparison with v2.",
        "- For production-level scene recognition, expand toward 1,000-1,500 images before judging final accuracy.",
        ""
    ]
    lines.append(contentsOf: markdownTable(for: "Train Counts", counts: trainCounts, scenes: scenes))
    lines.append(contentsOf: markdownTable(for: "Validation Counts", counts: validationCounts, scenes: scenes))
    lines.append(contentsOf: markdownTable(for: "Test Counts", counts: testCounts, scenes: scenes))

    try lines.joined(separator: "\n").write(to: reportURL, atomically: true, encoding: .utf8)

    print("Training accuracy: \(percent(accuracy(from: trainingMetrics)))")
    print("Validation accuracy: \(percent(accuracy(from: validationMetrics)))")
    print("Test accuracy: \(percent(accuracy(from: testMetrics)))")
    print("Wrote model: \(outputModelURL.path)")
    print("Wrote report: \(reportURL.path)")
} catch {
    fputs("Training failed: \(error)\n", stderr)
    exit(1)
}
