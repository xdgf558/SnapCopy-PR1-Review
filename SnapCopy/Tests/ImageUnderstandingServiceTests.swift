import XCTest
import UIKit
@testable import SnapCopy

final class ImageUnderstandingServiceTests: XCTestCase {
    func testSceneMapperDetectsFoodAndCoffee() {
        let tags = ImageSceneMapper.sceneTags(from: ["coffee cup", "breakfast food"])

        XCTAssertTrue(tags.contains("coffee"))
        XCTAssertTrue(tags.contains("food"))
    }

    func testSceneMapperDetectsPet() {
        let tags = ImageSceneMapper.sceneTags(from: ["dog", "animal"])

        XCTAssertTrue(tags.contains("pet"))
    }

    func testSceneMapperUsesOCRTextForWorkContext() {
        let tags = ImageSceneMapper.sceneTags(from: ["会议计划", "calendar notes"])

        XCTAssertTrue(tags.contains("work"))
        XCTAssertTrue(tags.contains("desk"))
    }

    func testFeatureDetectorDoesNotTreatDresserFurnitureAsPerson() {
        let flags = ImageFeatureDetector.flags(
            labels: [
                VisionImageLabel(name: "dresser", confidence: 0.82),
                VisionImageLabel(name: "furniture", confidence: 0.76),
                VisionImageLabel(name: "room", confidence: 0.64)
            ],
            texts: []
        )

        XCTAssertFalse(flags.hasPerson)
        XCTAssertFalse(flags.hasPet)
        XCTAssertTrue(flags.hasBuilding == false)
    }

    func testSceneResolverInfersCafeFromCombinedSignals() {
        let labels = [
            VisionImageLabel(name: "coffee cup", confidence: 0.82),
            VisionImageLabel(name: "table", confidence: 0.74),
            VisionImageLabel(name: "indoor", confidence: 0.62)
        ]

        let resolution = SceneResolver().resolve(labels: labels)

        XCTAssertEqual(resolution.scene, .cafe)
        XCTAssertGreaterThanOrEqual(resolution.confidence, 0.75)
        XCTAssertTrue(resolution.signals.contains { $0.contains("coffee") })
    }

    func testSceneResolverInfersPetFromAnimalLabels() {
        let labels = [
            VisionImageLabel(name: "cat", confidence: 0.91),
            VisionImageLabel(name: "chair", confidence: 0.65)
        ]

        let resolution = SceneResolver().resolve(labels: labels)

        XCTAssertEqual(resolution.scene, .pet)
        XCTAssertGreaterThanOrEqual(resolution.confidence, 0.9)
    }

    func testSceneResolverKeepsPetDiningRelationship() {
        let labels = [
            VisionImageLabel(name: "tableware", confidence: 0.88),
            VisionImageLabel(name: "utensil", confidence: 0.88),
            VisionImageLabel(name: "plate", confidence: 0.88),
            VisionImageLabel(name: "cat", confidence: 0.82),
            VisionImageLabel(name: "feline", confidence: 0.82)
        ]

        let resolution = SceneResolver().resolve(labels: labels)

        XCTAssertEqual(resolution.scene, .pet)
        XCTAssertEqual(resolution.subScene, "pet-dining-table")
        XCTAssertTrue(resolution.signals.contains("pet + food/tableware relationship"))
    }

    func testSceneFusionReturnsTopThreeCandidates() {
        let labels = [
            VisionImageLabel(name: "coffee cup", confidence: 0.86),
            VisionImageLabel(name: "table", confidence: 0.72),
            VisionImageLabel(name: "croissant", confidence: 0.62)
        ]
        let texts = [
            RecognizedTextObservation(text: "Morning coffee", confidence: 0.75)
        ]

        let resolution = SceneResolver().resolve(labels: labels, texts: texts)

        XCTAssertEqual(resolution.scene, .cafe)
        XCTAssertFalse(resolution.topCandidates.isEmpty)
        XCTAssertLessThanOrEqual(resolution.topCandidates.count, 3)
        XCTAssertTrue(resolution.topCandidates.contains { $0.scene == .cafe })
        XCTAssertTrue(resolution.fusionExplanation.contains("Top 3"))
    }

    func testSceneFusionUsesCustomModelPredictionWhenAvailable() {
        let labels = [
            VisionImageLabel(name: "object", confidence: 0.55),
            VisionImageLabel(name: "light", confidence: 0.44)
        ]
        let customPrediction = ScenePrediction(
            scene: .work,
            confidence: 0.92,
            source: .customModel,
            explanation: "Lightweight model recognized a work desk."
        )

        let resolution = SceneResolver().resolve(
            labels: labels,
            customPredictions: [customPrediction]
        )

        XCTAssertEqual(resolution.scene, .work)
        XCTAssertEqual(resolution.topCandidates.first?.source, .customModel)
    }

    func testCoreMLSceneClassifierLoadsBundledModelAndCanStillFallbackWhenMissing() async {
        let result = await CoreMLSceneClassifier().classify(UIImage())

        XCTAssertEqual(result.status, .available)

        let missingResult = await CoreMLSceneClassifier(modelResourceName: "MissingSceneClassifierForTests").classify(UIImage())

        XCTAssertEqual(missingResult.status, .disabled)
        XCTAssertTrue(missingResult.predictions.isEmpty)
    }

    func testRecognitionMetricsLoggerStoresLocalDebugRecord() {
        let defaults = UserDefaults(suiteName: "ImageRecognitionMetricsLoggerTests")!
        defaults.removePersistentDomain(forName: "ImageRecognitionMetricsLoggerTests")
        let logger = ImageRecognitionMetricsLogger(defaults: defaults, storageKey: "metrics.tests")
        let analysis = ImageAnalysisResult(
            visionLabels: [
                VisionImageLabel(name: "cat", confidence: 0.9)
            ],
            recognizedTexts: [],
            visualTraits: .empty,
            featureFlags: ImageFeatureFlags(
                hasPerson: false,
                hasFood: false,
                hasPet: true,
                hasStreet: false,
                hasBuilding: false,
                hasSky: false,
                hasPlant: false
            ),
            sceneResolution: SceneResolution(
                scene: .pet,
                subScene: "pet-animal-label",
                confidence: 0.94,
                signals: ["pet/animal label"],
                topCandidates: [
                    ScenePrediction(scene: .pet, confidence: 0.94, source: .ruleBased)
                ],
                fusionExplanation: "test"
            ),
            analysisLatencyMs: 12
        )

        logger.recordPrediction(result: analysis, imageSize: CGSize(width: 1200, height: 900))

        let records = logger.loadRecords()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.predictedScene, .pet)
        XCTAssertEqual(records.first?.top3Scenes, [.pet])
        XCTAssertEqual(records.first?.imageSize, "1200x900")

        let exportData = logger.makeExportData(appVersion: "v-test")
        XCTAssertNotNil(exportData)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try? decoder.decode(ImageRecognitionMetricsExport.self, from: exportData ?? Data())
        XCTAssertEqual(export?.schemaVersion, 1)
        XCTAssertEqual(export?.appVersion, "v-test")
        XCTAssertEqual(export?.recordCount, 1)
    }

    func testSemanticInterpreterBuildsPetDiningFocusFromCombinedLabels() {
        let labels = [
            VisionImageLabel(name: "tableware", confidence: 0.88),
            VisionImageLabel(name: "utensil", confidence: 0.88),
            VisionImageLabel(name: "plate", confidence: 0.88),
            VisionImageLabel(name: "fork", confidence: 0.74),
            VisionImageLabel(name: "cat", confidence: 0.82)
        ]
        let flags = ImageFeatureDetector.flags(labels: labels, texts: [])
        let sceneResolution = SceneResolver().resolve(labels: labels)

        let semanticSummary = ImageSemanticInterpreter.summary(
            labels: labels,
            texts: [],
            visualTraits: ImageVisualTraits(
                brightness: .dim,
                colorTemperature: .warm,
                saturation: .vivid,
                aspect: .landscape,
                dominantColors: ["dark", "orange", "red"]
            ),
            featureFlags: flags,
            sceneResolution: sceneResolution
        )

        XCTAssertTrue(semanticSummary.captionFocus?.contains("pet-and-meal relationship") == true)
        XCTAssertTrue(semanticSummary.subjectCues.contains("cat"))
        XCTAssertTrue(semanticSummary.objectCues.contains("plate"))
        XCTAssertTrue(semanticSummary.actionCues.contains("pet in a human-like dining setup"))
        XCTAssertTrue(semanticSummary.relationshipCues.contains("pet + food/tableware"))
        XCTAssertTrue(semanticSummary.atmosphereCues.contains("low light"))
    }

    func testCaptionContextBuilderExportsStructuredJSON() {
        var preference = UserPreference.default
        preference.setPreferredPlatforms([.xiaohongshu])
        preference.setPreferredLengthLevel(.long)
        let analysis = ImageAnalysisResult(
            visionLabels: [
                VisionImageLabel(name: "laptop", confidence: 0.91),
                VisionImageLabel(name: "desk", confidence: 0.84)
            ],
            recognizedTexts: [
                RecognizedTextObservation(text: "Project plan", confidence: 0.77)
            ],
            visualTraits: ImageVisualTraits(
                brightness: .dim,
                colorTemperature: .cool,
                saturation: .muted,
                aspect: .landscape,
                dominantColors: ["blue", "neutral"]
            ),
            featureFlags: ImageFeatureFlags(
                hasPerson: false,
                hasFood: false,
                hasPet: false,
                hasStreet: false,
                hasBuilding: false,
                hasSky: false,
                hasPlant: false
            ),
            sceneResolution: SceneResolution(
                scene: .work,
                subScene: "desk-computer-work",
                confidence: 0.86,
                signals: ["desk/computer/work"]
            )
        )
        let context = CaptionGenerationContext(analysisResult: analysis, manualScene: .auto)

        let prompt = CaptionGenerationPromptBuilder().makePrompt(context: context, preference: preference)

        XCTAssertTrue(prompt.contextJSON.contains("\"scene\" : \"work\""))
        XCTAssertTrue(prompt.contextJSON.contains("\"platform\" : \"xiaohongshu\""))
        XCTAssertTrue(prompt.contextJSON.contains("\"lengthLevel\" : \"long\""))
        XCTAssertTrue(prompt.prompt.contains("photo_context_json"))
        XCTAssertTrue(prompt.instructions.contains("Use only the provided photo_context_json as source of truth"))
        XCTAssertFalse(prompt.prompt.contains("Image context:"))
        XCTAssertFalse(prompt.prompt.contains("User preference:"))
    }

    func testCaptionContextBuilderExportsPetDiningFocus() {
        let labels = [
            VisionImageLabel(name: "tableware", confidence: 0.88),
            VisionImageLabel(name: "utensil", confidence: 0.88),
            VisionImageLabel(name: "plate", confidence: 0.88),
            VisionImageLabel(name: "cat", confidence: 0.82),
            VisionImageLabel(name: "feline", confidence: 0.82)
        ]
        let sceneResolution = SceneResolver().resolve(labels: labels)
        let semanticSummary = ImageSemanticInterpreter.summary(
            labels: labels,
            texts: [],
            visualTraits: ImageVisualTraits(
                brightness: .dim,
                colorTemperature: .warm,
                saturation: .vivid,
                aspect: .landscape,
                dominantColors: ["dark", "orange", "red"]
            ),
            featureFlags: ImageFeatureFlags(
                hasPerson: false,
                hasFood: true,
                hasPet: true,
                hasStreet: false,
                hasBuilding: false,
                hasSky: false,
                hasPlant: false
            ),
            sceneResolution: sceneResolution
        )
        let analysis = ImageAnalysisResult(
            visionLabels: labels,
            recognizedTexts: [],
            visualTraits: ImageVisualTraits(
                brightness: .dim,
                colorTemperature: .warm,
                saturation: .vivid,
                aspect: .landscape,
                dominantColors: ["dark", "orange", "red"]
            ),
            featureFlags: ImageFeatureFlags(
                hasPerson: false,
                hasFood: true,
                hasPet: true,
                hasStreet: false,
                hasBuilding: false,
                hasSky: false,
                hasPlant: false
            ),
            sceneResolution: sceneResolution,
            semanticSummary: semanticSummary
        )
        let context = CaptionGenerationContext(analysisResult: analysis, manualScene: .auto)

        let prompt = CaptionGenerationPromptBuilder().makePrompt(context: context, preference: .default)

        XCTAssertTrue(prompt.contextJSON.contains("\"captionFocus\""))
        XCTAssertTrue(prompt.contextJSON.contains("cat"))
        XCTAssertTrue(prompt.contextJSON.contains("plate"))
        XCTAssertTrue(prompt.contextJSON.contains("pet + food/tableware"))
        XCTAssertTrue(prompt.contextJSON.contains("\"semanticSummary\""))
        XCTAssertTrue(prompt.contextJSON.contains("\"actionCues\""))
        XCTAssertTrue(prompt.contextJSON.contains("pet-and-meal relationship"))
        XCTAssertTrue(prompt.contextJSON.contains("\"mustMentionCues\""))
        XCTAssertTrue(prompt.contextJSON.contains("\"avoidUnsupportedClaims\""))
        XCTAssertTrue(prompt.prompt.contains("image.captionFocus is present"))
        XCTAssertTrue(prompt.prompt.contains("image.mustMentionCues"))
        XCTAssertTrue(prompt.prompt.contains("image.actionCues"))
    }

    func testManualSceneOverridesVisionContext() {
        let visionResult = ImageUnderstandingResult(
            sceneTags: ["street", "city"],
            detectedLabels: [ImageUnderstandingLabel(name: "street", confidence: 0.8)],
            detectedTexts: ["Project plan"],
            visualTraits: ImageVisualTraits(
                brightness: .bright,
                colorTemperature: .warm,
                saturation: .natural,
                aspect: .landscape,
                dominantColors: ["light", "orange"]
            )
        )

        let context = CaptionGenerationContext(visionResult: visionResult, manualScene: .coffee)

        XCTAssertTrue(context.sceneTags.contains("coffee"))
        XCTAssertFalse(context.sceneTags.contains("street"))
        XCTAssertEqual(context.source, .manual)
        XCTAssertEqual(context.primaryScene, .food)
        XCTAssertTrue(context.hasImageDetails)
        XCTAssertTrue(context.imageDescription?.contains("Manual scene: 咖啡") == true)
        XCTAssertTrue(context.imageDescription?.contains("Visible text OCR: Project plan") == true)
        XCTAssertTrue(context.imageDescription?.contains("Visual traits") == true)
    }

    func testVisionContextUsesDetectedTagsWhenManualIsAuto() {
        let visionResult = ImageUnderstandingResult(
            sceneTags: ["pet", "daily"],
            detectedLabels: [ImageUnderstandingLabel(name: "cat", confidence: 0.9)]
        )

        let context = CaptionGenerationContext(visionResult: visionResult, manualScene: .auto)

        XCTAssertEqual(context.sceneTags, ["pet", "daily"])
        XCTAssertEqual(context.source, .vision)
        XCTAssertEqual(context.primaryScene, .pet)
    }

    func testVisionContextUsesRichDescriptionEvenWithoutSceneTags() {
        let visionResult = ImageUnderstandingResult(
            sceneTags: [],
            detectedLabels: [],
            detectedTexts: ["To do"],
            visualTraits: ImageVisualTraits(
                brightness: .bright,
                colorTemperature: .warm,
                saturation: .natural,
                aspect: .portrait,
                dominantColors: ["light", "orange"]
            )
        )

        let context = CaptionGenerationContext(visionResult: visionResult, manualScene: .auto)

        XCTAssertEqual(context.source, .vision)
        XCTAssertEqual(context.sceneTags, [])
        XCTAssertTrue(context.imageDescription?.contains("Visible text OCR") == true)
        XCTAssertTrue(context.imageDescription?.contains("Visual traits") == true)
    }

    func testPromptDescriptionIncludesVisualTraitsAndOCR() {
        let visionResult = ImageUnderstandingResult(
            sceneTags: ["work", "desk"],
            detectedLabels: [ImageUnderstandingLabel(name: "laptop", confidence: 0.8)],
            detectedTexts: ["Project plan"],
            visualTraits: ImageVisualTraits(
                brightness: .dim,
                colorTemperature: .cool,
                saturation: .muted,
                aspect: .landscape,
                dominantColors: ["blue", "neutral"]
            )
        )

        let description = visionResult.promptDescription ?? ""

        XCTAssertTrue(description.contains("Vision labels: laptop"))
        XCTAssertTrue(description.contains("Visible text OCR: Project plan"))
        XCTAssertTrue(description.contains("brightness=dim"))
        XCTAssertTrue(description.contains("dominantColors=blue, neutral"))
    }

    func testGenerationPromptIncludesRichImageDetails() {
        let visionResult = ImageUnderstandingResult(
            sceneTags: ["work", "desk"],
            detectedLabels: [
                ImageUnderstandingLabel(name: "laptop", confidence: 0.91),
                ImageUnderstandingLabel(name: "notebook", confidence: 0.78)
            ],
            detectedTexts: ["Project plan"],
            visualTraits: ImageVisualTraits(
                brightness: .dim,
                colorTemperature: .cool,
                saturation: .muted,
                aspect: .landscape,
                dominantColors: ["blue", "neutral"]
            )
        )
        let context = CaptionGenerationContext(visionResult: visionResult, manualScene: .auto)

        let generationPrompt = CaptionGenerationPromptBuilder().makePrompt(
            context: context,
            preference: .default
        )

        XCTAssertTrue(generationPrompt.instructions.contains("Prefer concrete visual evidence over broad scene labels"))
        XCTAssertTrue(generationPrompt.prompt.contains("\"sceneTags\""))
        XCTAssertTrue(generationPrompt.prompt.contains("work"))
        XCTAssertTrue(generationPrompt.prompt.contains("desk"))
        XCTAssertTrue(generationPrompt.prompt.contains("Vision labels: laptop, notebook"))
        XCTAssertTrue(generationPrompt.prompt.contains("Visible text OCR: Project plan"))
        XCTAssertTrue(generationPrompt.prompt.contains("brightness=dim"))
        XCTAssertTrue(generationPrompt.prompt.contains("dominantColors=blue, neutral"))
        XCTAssertTrue(generationPrompt.prompt.contains("At least 3 of the 5 captions must visibly reflect"))
        XCTAssertTrue(generationPrompt.prompt.contains("use at least two different cue types"))
        XCTAssertTrue(generationPrompt.prompt.contains("Avoid generic scene-label templates"))
    }

    func testGenerationPromptUsesSelectedLanguage() {
        var preference = UserPreference.default
        preference.setPreferredCaptionLanguage(.japanese)

        let generationPrompt = CaptionGenerationPromptBuilder().makePrompt(
            context: .empty,
            preference: preference
        )

        XCTAssertTrue(generationPrompt.instructions.contains("Output every caption in Japanese"))
        XCTAssertTrue(generationPrompt.prompt.contains("Generate 5 caption options"))
        XCTAssertTrue(generationPrompt.prompt.contains("Every caption text must be written in Japanese"))
        XCTAssertTrue(generationPrompt.contextJSON.contains("\"outputLanguage\" : \"ja-JP\""))
        XCTAssertFalse(generationPrompt.prompt.contains("Simplified Chinese caption options"))
    }

    func testGenerationPromptKeepsImageDetailsWhenManualSceneIsSelected() {
        let visionResult = ImageUnderstandingResult(
            sceneTags: ["pet", "daily"],
            detectedLabels: [ImageUnderstandingLabel(name: "cat", confidence: 0.94)],
            detectedTexts: ["Happy"],
            visualTraits: ImageVisualTraits(
                brightness: .bright,
                colorTemperature: .warm,
                saturation: .natural,
                aspect: .portrait,
                dominantColors: ["orange", "white"]
            )
        )
        let context = CaptionGenerationContext(visionResult: visionResult, manualScene: .work)

        let generationPrompt = CaptionGenerationPromptBuilder().makePrompt(
            context: context,
            preference: .default
        )

        XCTAssertTrue(context.hasImageDetails)
        XCTAssertTrue(generationPrompt.prompt.contains("\"sceneTags\""))
        XCTAssertTrue(generationPrompt.prompt.contains("work"))
        XCTAssertTrue(generationPrompt.prompt.contains("desk"))
        XCTAssertTrue(generationPrompt.prompt.contains("daily"))
        XCTAssertTrue(generationPrompt.prompt.contains("Manual scene: 工作"))
        XCTAssertTrue(generationPrompt.prompt.contains("Vision labels: cat"))
        XCTAssertTrue(generationPrompt.prompt.contains("Visible text OCR: Happy"))
        XCTAssertTrue(generationPrompt.prompt.contains("brightness=bright"))
        XCTAssertTrue(generationPrompt.prompt.contains("dominantColors=orange, white"))
        XCTAssertTrue(generationPrompt.prompt.contains("Use these cues as anchors, not just sceneTags"))
    }
}
