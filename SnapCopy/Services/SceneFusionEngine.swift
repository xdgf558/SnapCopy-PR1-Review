import Foundation

struct SceneFusionEngine {
    func fuse(
        visionLabels: [VisionImageLabel],
        ocrTexts: [RecognizedTextObservation],
        customModelPredictions: [ScenePrediction],
        userCorrectionHistory: [ScenePrediction],
        ruleBasedPredictions: [ScenePrediction]
    ) -> SceneFusionResult {
        let visionPredictions = predictionsFromLabels(visionLabels)
        let ocrPredictions = predictionsFromTexts(ocrTexts)
        let allPredictions = visionPredictions +
        ocrPredictions +
        customModelPredictions +
        userCorrectionHistory +
        ruleBasedPredictions
        let hasCustomModelPredictions = !customModelPredictions.isEmpty

        guard !allPredictions.isEmpty else {
            return .unknown
        }

        var weightedScores: [SceneType: Double] = [:]
        var sourceExplanations: [SceneType: [String]] = [:]

        for prediction in allPredictions where prediction.scene != .unknown {
            let score = prediction.confidence * weight(for: prediction.source, hasCustomModelPredictions: hasCustomModelPredictions)
            weightedScores[prediction.scene, default: 0] += score
            sourceExplanations[prediction.scene, default: []].append(explanation(for: prediction, weightedScore: score))
        }

        guard !weightedScores.isEmpty else {
            return .unknown
        }

        let sortedScores = weightedScores.sorted { lhs, rhs in
            lhs.value == rhs.value ? lhs.key.rawValue < rhs.key.rawValue : lhs.value > rhs.value
        }
        let maxScore = sortedScores.first?.value ?? 0
        let topCandidates = sortedScores.prefix(3).map { scene, score in
            ScenePrediction(
                scene: scene,
                confidence: normalizedConfidence(score, maxScore: maxScore),
                source: dominantSource(
                    for: scene,
                    predictions: allPredictions,
                    hasCustomModelPredictions: hasCustomModelPredictions
                ),
                explanation: sourceExplanations[scene]?.prefix(4).joined(separator: "; ") ?? ""
            )
        }
        let finalCandidate = topCandidates.first
        let finalScene = finalCandidate?.scene ?? .unknown
        let confidence = finalCandidate?.confidence ?? 0
        let explanation = explanationText(
            finalScene: finalScene,
            topCandidates: topCandidates,
            sourceExplanations: sourceExplanations[finalScene] ?? []
        )

        return SceneFusionResult(
            topCandidates: topCandidates,
            finalScene: confidence < 0.32 ? .unknown : finalScene,
            confidence: confidence,
            explanation: explanation
        )
    }

    private func predictionsFromLabels(_ labels: [VisionImageLabel]) -> [ScenePrediction] {
        labels.flatMap { label -> [ScenePrediction] in
            let text = label.name.lowercased()
            return sceneMatches(in: text).map { scene in
                ScenePrediction(
                    scene: scene,
                    confidence: label.confidence,
                    source: .vision,
                    explanation: "Vision label '\(label.name)'"
                )
            }
        }
    }

    private func predictionsFromTexts(_ texts: [RecognizedTextObservation]) -> [ScenePrediction] {
        texts.flatMap { observation -> [ScenePrediction] in
            let text = observation.text.lowercased()
            return sceneMatches(in: text).map { scene in
                ScenePrediction(
                    scene: scene,
                    confidence: observation.confidence,
                    source: .ocr,
                    explanation: "OCR text '\(observation.text)'"
                )
            }
        }
    }

    private func sceneMatches(in text: String) -> [SceneType] {
        var scenes: [SceneType] = []

        func add(_ scene: SceneType, keywords: [String]) {
            if keywords.contains(where: { text.contains($0) }) {
                scenes.append(scene)
            }
        }

        add(.breakfast, keywords: ["breakfast", "brunch", "toast", "egg", "bread", "pancake", "croissant", "morning", "早餐"])
        add(.cafe, keywords: ["coffee", "espresso", "latte", "cappuccino", "cafe", "cup", "mug", "咖啡"])
        add(.walking, keywords: ["walk", "walking", "sidewalk", "path", "park", "trail", "散步"])
        add(.street, keywords: ["street", "city", "urban", "building", "architecture", "traffic", "road", "街", "楼"])
        add(.travel, keywords: ["travel", "trip", "landscape", "mountain", "beach", "ocean", "sea", "hotel", "airport", "landmark", "旅行"])
        add(.pet, keywords: ["cat", "dog", "pet", "animal", "puppy", "kitten", "feline", "canine", "猫", "狗"])
        add(.outfit, keywords: ["person", "people", "portrait", "clothing", "dress", "shoe", "bag", "fashion", "outfit", "mirror", "穿搭"])
        add(.fitness, keywords: ["gym", "fitness", "workout", "running", "yoga", "exercise", "sport", "运动", "健身"])
        add(.sunset, keywords: ["sunset", "sunrise", "dusk", "twilight", "orange sky", "晚霞", "日落"])
        add(.home, keywords: ["home", "room", "sofa", "bed", "living room", "kitchen", "interior", "chair", "室内", "家"])
        add(.work, keywords: ["desk", "laptop", "computer", "keyboard", "notebook", "document", "monitor", "office", "screen", "meeting", "calendar", "电脑", "办公", "工作"])
        add(.food, keywords: ["food", "meal", "dish", "restaurant", "cuisine", "dessert", "cake", "steak", "meat", "beef", "plate", "bowl", "餐", "饭", "菜", "肉", "牛排"])

        return scenes.uniqued()
    }

    private func weight(for source: PredictionSource, hasCustomModelPredictions: Bool) -> Double {
        switch source {
        case .userCorrection:
            return 0.10
        case .customModel:
            return hasCustomModelPredictions ? 0.60 : 0
        case .ruleBased:
            return hasCustomModelPredictions ? 0.25 : 0.80
        case .vision:
            return hasCustomModelPredictions ? 0.08 : 0.20
        case .ocr:
            return hasCustomModelPredictions ? 0.05 : 0.10
        }
    }

    private func normalizedConfidence(_ score: Double, maxScore: Double) -> Double {
        guard maxScore > 0 else {
            return 0
        }

        let relative = score / maxScore
        let absolute = min(0.98, score)
        return min(0.98, max(0.32, absolute * 0.72 + relative * 0.26))
    }

    private func dominantSource(
        for scene: SceneType,
        predictions: [ScenePrediction],
        hasCustomModelPredictions: Bool
    ) -> PredictionSource {
        predictions
            .filter { $0.scene == scene }
            .max { lhs, rhs in
                lhs.confidence * weight(for: lhs.source, hasCustomModelPredictions: hasCustomModelPredictions) <
                rhs.confidence * weight(for: rhs.source, hasCustomModelPredictions: hasCustomModelPredictions)
            }?
            .source ?? .ruleBased
    }

    private func explanation(for prediction: ScenePrediction, weightedScore: Double) -> String {
        let detail = prediction.explanation.isEmpty ? prediction.source.rawValue : prediction.explanation
        return "\(prediction.source.rawValue): \(prediction.scene.rawValue) \(Int((prediction.confidence * 100).rounded()))% (\(String(format: "%.2f", weightedScore))) - \(detail)"
    }

    private func explanationText(
        finalScene: SceneType,
        topCandidates: [ScenePrediction],
        sourceExplanations: [String]
    ) -> String {
        let ranking = topCandidates.map { "\($0.scene.rawValue) \(Int(($0.confidence * 100).rounded()))%" }.joined(separator: ", ")
        let sources = sourceExplanations.prefix(6).joined(separator: "\n")

        return """
        Final scene: \(finalScene.rawValue)
        Top 3: \(ranking.isEmpty ? "none" : ranking)
        Sources:
        \(sources.isEmpty ? "none" : sources)
        """
    }
}

private extension Array where Element == SceneType {
    func uniqued() -> [SceneType] {
        var seen: Set<SceneType> = []

        return filter { item in
            guard !seen.contains(item) else {
                return false
            }

            seen.insert(item)
            return true
        }
    }
}
