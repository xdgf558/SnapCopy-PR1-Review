import CreateML
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let datasetRoot = root.appendingPathComponent("generated_scene_dataset/dataset")
let trainURL = datasetRoot.appendingPathComponent("train")
let validationURL = datasetRoot.appendingPathComponent("validation")
let testURL = datasetRoot.appendingPathComponent("test")
let outputDirectory = root.appendingPathComponent("models")
let outputURL = outputDirectory.appendingPathComponent("SnapCopySceneClassifier.mlmodel")

func requireDirectory(_ url: URL) throws {
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
        throw NSError(
            domain: "SnapCopyTraining",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Missing directory: \(url.path)"]
        )
    }
}

func imageURLsByLabel(in root: URL) throws -> [String: [URL]] {
    let labels = try FileManager.default.contentsOfDirectory(
        at: root,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
    )
    var result: [String: [URL]] = [:]

    for labelURL in labels {
        let values = try labelURL.resourceValues(forKeys: [.isDirectoryKey])
        guard values.isDirectory == true else { continue }
        let files = try FileManager.default.contentsOfDirectory(
            at: labelURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .filter { ["jpg", "jpeg", "png"].contains($0.pathExtension.lowercased()) }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
        result[labelURL.lastPathComponent] = files
    }

    return result
}

func printDatasetSummary(_ title: String, _ labels: [String: [URL]]) {
    print("\n\(title)")
    for label in labels.keys.sorted() {
        print("  \(label): \(labels[label]?.count ?? 0)")
    }
}

func evaluateManually(_ classifier: MLImageClassifier, testingData: [String: [URL]]) throws -> (correct: Int, total: Int) {
    var correct = 0
    var total = 0
    var confusion: [String: [String: Int]] = [:]

    for label in testingData.keys.sorted() {
        for imageURL in testingData[label, default: []] {
            let prediction = try classifier.prediction(from: imageURL)
            confusion[label, default: [:]][prediction, default: 0] += 1
            total += 1
            if prediction == label {
                correct += 1
            }
        }
    }

    print("\nManual test predictions")
    for actual in confusion.keys.sorted() {
        let parts = confusion[actual, default: [:]]
            .sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: ", ")
        print("  \(actual) -> \(parts)")
    }

    return (correct, total)
}

do {
    try requireDirectory(trainURL)
    try requireDirectory(validationURL)
    try requireDirectory(testURL)
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

    let trainingLabels = try imageURLsByLabel(in: trainURL)
    let validationLabels = try imageURLsByLabel(in: validationURL)
    let testingLabels = try imageURLsByLabel(in: testURL)

    printDatasetSummary("Training data", trainingLabels)
    printDatasetSummary("Validation data", validationLabels)
    printDatasetSummary("Test data", testingLabels)

    let trainingData = MLImageClassifier.DataSource.labeledDirectories(at: trainURL)
    let validationData = MLImageClassifier.DataSource.labeledDirectories(at: validationURL)
    let testingData = MLImageClassifier.DataSource.labeledDirectories(at: testURL)

    let parameters = MLImageClassifier.ModelParameters(
        validation: .dataSource(validationData),
        maxIterations: 25,
        augmentation: [.crop, .exposure, .blur],
        algorithm: .transferLearning(
            featureExtractor: .scenePrint(revision: 1),
            classifier: .logisticRegressor
        )
    )

    print("\nTraining SnapCopySceneClassifier...")
    let start = Date()
    let classifier = try MLImageClassifier(trainingData: trainingData, parameters: parameters)
    let elapsed = Date().timeIntervalSince(start)

    print("\nTraining finished in \(String(format: "%.1f", elapsed)) seconds")
    print("Training metrics: \(classifier.trainingMetrics)")
    print("Validation metrics: \(classifier.validationMetrics)")

    let testMetrics = classifier.evaluation(on: testingData)
    print("Test metrics: \(testMetrics)")

    let manual = try evaluateManually(classifier, testingData: testingLabels)
    let manualAccuracy = manual.total == 0 ? 0 : Double(manual.correct) / Double(manual.total)
    print("\nManual test accuracy: \(manual.correct)/\(manual.total) = \(String(format: "%.2f%%", manualAccuracy * 100))")

    if FileManager.default.fileExists(atPath: outputURL.path) {
        try FileManager.default.removeItem(at: outputURL)
    }
    try classifier.write(to: outputURL)
    print("\nSaved model:")
    print(outputURL.path)
} catch {
    fputs("Training failed: \(error)\n", stderr)
    exit(1)
}

