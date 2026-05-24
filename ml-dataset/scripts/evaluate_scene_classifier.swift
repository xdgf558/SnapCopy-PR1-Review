#!/usr/bin/env swift
import CoreGraphics
import CoreML
import Foundation
import ImageIO
import Vision

struct EvaluationResult {
    let name: String
    let total: Int
    let top1Correct: Int
    let top3Correct: Int
    let perClass: [String: (total: Int, top1: Int, top3: Int)]

    var top1Accuracy: Double {
        total == 0 ? 0 : Double(top1Correct) / Double(total)
    }

    var top3Coverage: Double {
        total == 0 ? 0 : Double(top3Correct) / Double(total)
    }
}

struct TestImage {
    let label: String
    let url: URL
}

enum EvaluationError: Error, CustomStringConvertible {
    case missingModel(String)
    case missingDataset(String)
    case unreadableImage(String)
    case noClassification(String)

    var description: String {
        switch self {
        case .missingModel(let path):
            return "Missing model: \(path)"
        case .missingDataset(let path):
            return "Missing dataset: \(path)"
        case .unreadableImage(let path):
            return "Unreadable image: \(path)"
        case .noClassification(let path):
            return "No classification result for image: \(path)"
        }
    }
}

let fileManager = FileManager.default
let repoRoot = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let testRoot = repoRoot.appendingPathComponent("ml-dataset/v1_clean/test", isDirectory: true)
let oldModelURL = repoRoot.appendingPathComponent("ml-dataset/exports/CaptionSceneClassifier_v1.mlmodel")
let cleanModelURL = repoRoot.appendingPathComponent("ml-dataset/exports/CaptionSceneClassifier_v1_clean.mlmodel")
let reportURL = repoRoot.appendingPathComponent("ml-dataset/reports/v1_model_comparison_report.md")

func percent(_ value: Double) -> String {
    String(format: "%.2f%%", value * 100)
}

func loadTestImages() throws -> [TestImage] {
    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: testRoot.path, isDirectory: &isDirectory), isDirectory.boolValue else {
        throw EvaluationError.missingDataset(testRoot.path)
    }

    let classURLs = try fileManager.contentsOfDirectory(
        at: testRoot,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
    )

    var images: [TestImage] = []
    for classURL in classURLs.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
        let values = try classURL.resourceValues(forKeys: [.isDirectoryKey])
        guard values.isDirectory == true else { continue }
        let files = try fileManager.contentsOfDirectory(
            at: classURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard ["jpg", "jpeg", "png", "heic"].contains(file.pathExtension.lowercased()) else { continue }
            images.append(TestImage(label: classURL.lastPathComponent, url: file))
        }
    }
    return images
}

func cgImage(from url: URL) throws -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw EvaluationError.unreadableImage(url.path)
    }
    return image
}

func loadVisionModel(from url: URL) throws -> VNCoreMLModel {
    guard fileManager.fileExists(atPath: url.path) else {
        throw EvaluationError.missingModel(url.path)
    }
    let compiledURL = try MLModel.compileModel(at: url)
    let configuration = MLModelConfiguration()
    configuration.computeUnits = .all
    let model = try MLModel(contentsOf: compiledURL, configuration: configuration)
    return try VNCoreMLModel(for: model)
}

func classify(_ image: TestImage, using model: VNCoreMLModel) throws -> [VNClassificationObservation] {
    let request = VNCoreMLRequest(model: model)
    request.imageCropAndScaleOption = .centerCrop
    let handler = VNImageRequestHandler(cgImage: try cgImage(from: image.url), options: [:])
    try handler.perform([request])
    guard let observations = request.results as? [VNClassificationObservation], !observations.isEmpty else {
        throw EvaluationError.noClassification(image.url.path)
    }
    return observations.sorted { $0.confidence > $1.confidence }
}

func evaluate(name: String, modelURL: URL, images: [TestImage]) throws -> EvaluationResult {
    let model = try loadVisionModel(from: modelURL)
    var top1Correct = 0
    var top3Correct = 0
    var perClass: [String: (total: Int, top1: Int, top3: Int)] = [:]

    for image in images {
        let observations = try classify(image, using: model)
        let top1 = observations.first?.identifier
        let top3 = observations.prefix(3).map(\.identifier)
        let isTop1 = top1 == image.label
        let isTop3 = top3.contains(image.label)
        if isTop1 { top1Correct += 1 }
        if isTop3 { top3Correct += 1 }

        var stats = perClass[image.label, default: (total: 0, top1: 0, top3: 0)]
        stats.total += 1
        if isTop1 { stats.top1 += 1 }
        if isTop3 { stats.top3 += 1 }
        perClass[image.label] = stats
    }

    return EvaluationResult(
        name: name,
        total: images.count,
        top1Correct: top1Correct,
        top3Correct: top3Correct,
        perClass: perClass
    )
}

do {
    let images = try loadTestImages()
    let oldResult = try evaluate(name: "v1_before_cleaning", modelURL: oldModelURL, images: images)
    let cleanResult = try evaluate(name: "v1_clean", modelURL: cleanModelURL, images: images)
    let top1Delta = cleanResult.top1Accuracy - oldResult.top1Accuracy
    let top3Delta = cleanResult.top3Coverage - oldResult.top3Coverage

    let scenes = Array(Set(images.map(\.label))).sorted()
    var lines: [String] = [
        "# v1 Model Comparison Report",
        "",
        "- Test set: `ml-dataset/v1_clean/test`",
        "- Test images: \(images.count)",
        "- Old model: `ml-dataset/exports/CaptionSceneClassifier_v1.mlmodel`",
        "- Clean model: `ml-dataset/exports/CaptionSceneClassifier_v1_clean.mlmodel`",
        "",
        "## Summary",
        "",
        "| Model | Top-1 Correct | Top-1 Accuracy | Top-3 Correct | Top-3 Coverage |",
        "|---|---:|---:|---:|---:|",
        "| \(oldResult.name) | \(oldResult.top1Correct)/\(oldResult.total) | \(percent(oldResult.top1Accuracy)) | \(oldResult.top3Correct)/\(oldResult.total) | \(percent(oldResult.top3Coverage)) |",
        "| \(cleanResult.name) | \(cleanResult.top1Correct)/\(cleanResult.total) | \(percent(cleanResult.top1Accuracy)) | \(cleanResult.top3Correct)/\(cleanResult.total) | \(percent(cleanResult.top3Coverage)) |",
        "",
        "## Delta",
        "",
        "- Top-1 accuracy delta: \(String(format: "%+.2f", top1Delta * 100)) percentage points",
        "- Top-3 coverage delta: \(String(format: "%+.2f", top3Delta * 100)) percentage points",
        "",
        "## Per-Class Top-1 Accuracy",
        "",
        "| Scene | Old | Clean | Delta |",
        "|---|---:|---:|---:|"
    ]

    for scene in scenes {
        let oldStats = oldResult.perClass[scene, default: (total: 0, top1: 0, top3: 0)]
        let cleanStats = cleanResult.perClass[scene, default: (total: 0, top1: 0, top3: 0)]
        let oldAccuracy = oldStats.total == 0 ? 0 : Double(oldStats.top1) / Double(oldStats.total)
        let cleanAccuracy = cleanStats.total == 0 ? 0 : Double(cleanStats.top1) / Double(cleanStats.total)
        lines.append("| \(scene) | \(oldStats.top1)/\(oldStats.total) \(percent(oldAccuracy)) | \(cleanStats.top1)/\(cleanStats.total) \(percent(cleanAccuracy)) | \(String(format: "%+.2f", (cleanAccuracy - oldAccuracy) * 100)) pp |")
    }

    try lines.joined(separator: "\n").write(to: reportURL, atomically: true, encoding: .utf8)
    print("Old Top-1: \(percent(oldResult.top1Accuracy))")
    print("Clean Top-1: \(percent(cleanResult.top1Accuracy))")
    print("Top-1 delta: \(String(format: "%+.2f", top1Delta * 100)) pp")
    print("Old Top-3: \(percent(oldResult.top3Coverage))")
    print("Clean Top-3: \(percent(cleanResult.top3Coverage))")
    print("Top-3 delta: \(String(format: "%+.2f", top3Delta * 100)) pp")
    print("Wrote report: \(reportURL.path)")
} catch {
    fputs("Evaluation failed: \(error)\n", stderr)
    exit(1)
}
