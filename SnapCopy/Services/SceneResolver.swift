import Foundation

struct SceneResolver {
    func resolve(_ result: ImageAnalysisResult) -> SceneResolution {
        resolve(
            labels: result.visionLabels,
            texts: result.recognizedTexts,
            visualTraits: result.visualTraits,
            customPredictions: result.customSceneClassification.predictions
        )
    }

    func resolve(
        labels: [VisionImageLabel],
        texts: [String] = [],
        visualTraits: ImageVisualTraits = .empty,
        customPredictions: [ScenePrediction] = [],
        userCorrections: [ScenePrediction] = []
    ) -> SceneResolution {
        resolve(
            labels: labels,
            texts: texts.map { RecognizedTextObservation(text: $0, confidence: 0.55) },
            visualTraits: visualTraits,
            customPredictions: customPredictions,
            userCorrections: userCorrections
        )
    }

    func resolve(
        labels: [VisionImageLabel],
        texts: [RecognizedTextObservation],
        visualTraits: ImageVisualTraits = .empty,
        customPredictions: [ScenePrediction] = [],
        userCorrections: [ScenePrediction] = []
    ) -> SceneResolution {
        var scores: [ProductScene: Double] = [:]
        var signals: [ProductScene: [String]] = [:]
        let labelText = (labels.map(\.name) + texts.map(\.text)).joined(separator: " ").lowercased()
        let hasPetSignal = contains(labelText, Self.petKeywords)
        let hasFoodSignal = contains(labelText, Self.foodKeywords)
        let hasDiningSignal = contains(labelText, Self.diningKeywords)

        func add(_ scene: ProductScene, _ points: Double, _ signal: String) {
            scores[scene, default: 0] += points
            signals[scene, default: []].append(signal)
        }

        if hasPetSignal {
            add(.pet, 0.95, "pet/animal label")
        }

        if contains(labelText, ["coffee", "espresso", "latte", "cappuccino", "cafe", "cup", "mug", "咖啡"]) {
            add(.cafe, 0.55, "coffee or cup")
        }

        if contains(labelText, ["table", "indoor", "restaurant", "bakery", "cafe", "chair", "桌", "店"]) {
            add(.cafe, 0.20, "table or indoor cafe context")
        }

        if contains(labelText, ["breakfast", "brunch", "toast", "egg", "bread", "pancake", "croissant", "morning", "早餐"]) {
            add(.breakfast, 0.70, "breakfast or morning food")
        }

        if hasFoodSignal || hasDiningSignal {
            add(.food, 0.58, "food/tableware")
            add(.breakfast, 0.14, "food supports breakfast when paired with morning context")
        }

        if hasPetSignal, hasFoodSignal || hasDiningSignal {
            add(.pet, 0.18, "pet + food/tableware relationship")
            add(.food, 0.14, "pet + food/tableware relationship")
        }

        if contains(labelText, ["sky", "sunset", "sunrise", "dusk", "twilight", "orange sky", "晚霞", "日落"]) {
            add(.sunset, 0.58, "sky/sunset light")
        }

        if visualTraits.colorTemperature == .warm, visualTraits.brightness != .dark {
            add(.sunset, 0.10, "warm bright light")
        }

        if contains(labelText, ["road", "sidewalk", "walk", "walking", "path", "park", "trail", "路", "散步"]) {
            add(.walking, 0.42, "road/path/walking")
        }

        if contains(labelText, ["street", "city", "urban", "building", "architecture", "skyline", "traffic", "街", "楼"]) {
            add(.street, 0.45, "street/city/building")
        }

        if contains(labelText, ["sky", "road", "building"]) {
            add(.street, 0.14, "sky + road/building combination")
            add(.walking, 0.10, "outdoor route combination")
        }

        if contains(labelText, ["travel", "trip", "landscape", "mountain", "beach", "ocean", "sea", "hotel", "airport", "train", "landmark", "vacation", "旅行"]) {
            add(.travel, 0.68, "travel or landscape label")
        }

        if contains(labelText, ["person", "people", "portrait", "clothing", "dress", "shoe", "bag", "fashion", "outfit", "穿搭", "衣"]) {
            add(.outfit, 0.45, "person/clothing/fashion")
        }

        if contains(labelText, ["gym", "fitness", "workout", "running", "yoga", "exercise", "sport", "运动", "健身"]) {
            add(.fitness, 0.82, "fitness/sport")
        }

        if contains(labelText, ["home", "room", "sofa", "bed", "living room", "kitchen", "interior", "chair", "室内", "家"]) {
            add(.home, 0.46, "home/interior")
        }

        if contains(labelText, ["desk", "laptop", "computer", "keyboard", "notebook", "document", "monitor", "office", "screen", "meeting", "calendar", "电脑", "办公", "工作"]) {
            add(.work, 0.72, "desk/computer/work")
        }

        if scores[.cafe, default: 0] >= 0.55, scores[.food, default: 0] >= 0.58 {
            add(.cafe, 0.16, "coffee + food/table context")
        }

        if scores[.cafe, default: 0] >= 0.55, scores[.breakfast, default: 0] >= 0.70 {
            add(.cafe, 0.18, "coffee-forward cafe context")
        }

        if scores[.breakfast, default: 0] >= 0.70, scores[.food, default: 0] >= 0.58 {
            add(.breakfast, 0.16, "breakfast + food combination")
        }

        let ruleBasedPredictions = scores.map { scene, score in
            ScenePrediction(
                scene: SceneType(productScene: scene),
                confidence: min(0.98, score),
                source: .ruleBased,
                explanation: (signals[scene] ?? []).uniqued().joined(separator: "; ")
            )
        }

        let fusionResult = SceneFusionEngine().fuse(
            visionLabels: labels,
            ocrTexts: texts,
            customModelPredictions: customPredictions,
            userCorrectionHistory: userCorrections,
            ruleBasedPredictions: ruleBasedPredictions
        )
        let scene = ProductScene(sceneType: fusionResult.finalScene)
        let selectedSignals = signals[scene] ?? fusionResult.topCandidates.first?.explanation.components(separatedBy: "; ") ?? []

        return SceneResolution(
            scene: scene,
            subScene: subScene(for: scene, signals: selectedSignals),
            confidence: fusionResult.confidence,
            signals: selectedSignals.uniqued(),
            topCandidates: fusionResult.topCandidates,
            fusionExplanation: fusionResult.explanation
        )
    }

    private func subScene(for scene: ProductScene, signals: [String]) -> String? {
        guard scene != .unknown else {
            return nil
        }

        if scene == .pet, signals.contains(where: { $0.contains("food/tableware") }) {
            return "pet-dining-table"
        }

        if signals.contains(where: { $0.contains("combination") }) {
            return "\(scene.rawValue)-combined"
        }

        return signals.first?
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
    }

    private func contains(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { keyword in
            text.contains(keyword.lowercased())
        }
    }

    private static let petKeywords = [
        "cat", "dog", "pet", "animal", "puppy", "kitten", "feline", "canine", "猫", "狗"
    ]

    private static let foodKeywords = [
        "food", "meal", "dish", "restaurant", "cuisine", "dessert", "cake",
        "steak", "meat", "beef", "breakfast", "brunch", "toast", "egg",
        "bread", "pancake", "croissant", "餐", "饭", "菜", "肉", "牛排"
    ]

    private static let diningKeywords = [
        "tableware", "utensil", "plate", "bowl", "fork", "knife", "spoon",
        "table", "dining", "餐具", "盘", "碗", "叉", "刀", "桌"
    ]
}

private extension Array where Element == String {
    func uniqued() -> [String] {
        var seen: Set<String> = []

        return filter { item in
            guard !seen.contains(item) else {
                return false
            }

            seen.insert(item)
            return true
        }
    }
}
