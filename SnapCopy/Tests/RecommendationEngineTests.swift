import UIKit
import XCTest
@testable import SnapCopy

final class RecommendationEngineTests: XCTestCase {
    func testFeedbackCollectorMapsActionsToRewards() {
        let collector = FeedbackCollector()

        XCTAssertEqual(collector.rewardScore(for: .rating(5)), 1.0)
        XCTAssertEqual(collector.rewardScore(for: .rating(4)), 0.6)
        XCTAssertEqual(collector.rewardScore(for: .rating(3)), 0.1)
        XCTAssertEqual(collector.rewardScore(for: .rating(2)), -0.4)
        XCTAssertEqual(collector.rewardScore(for: .rating(1)), -1.0)
        XCTAssertEqual(collector.rewardScore(for: .copyCaption), 0.7)
        XCTAssertEqual(collector.rewardScore(for: .shareCaption), 0.9)
        XCTAssertEqual(collector.rewardScore(for: .editedFinalCaptionUsed), 1.3)
        XCTAssertEqual(collector.rewardScore(for: .saveCaption), 0.6)
        XCTAssertEqual(collector.rewardScore(for: .regenerate), -0.4)
        XCTAssertEqual(collector.rewardScore(for: .deleteCaption), -0.6)
        XCTAssertEqual(collector.rewardScore(for: .markExternalGoodFeedback), 1.2)
    }

    func testFeedbackCollectorAppliesDwellTimeWeighting() {
        let collector = FeedbackCollector()

        XCTAssertEqual(collector.rewardScore(for: .shareCaption, dwellSeconds: 20), 1.1, accuracy: 0.001)
        XCTAssertEqual(collector.rewardScore(for: .regenerate, dwellSeconds: 20), -0.6, accuracy: 0.001)
        XCTAssertEqual(collector.rewardScore(for: .copyCaption, dwellSeconds: 1), 0.7, accuracy: 0.001)
    }

    func testRecommendationPreferenceLearnsFromExplorationFeedback() {
        let collector = FeedbackCollector()
        let caption = CaptionCandidate(
            text: "这只猫把餐桌气氛拿捏住了。",
            style: .humor,
            platform: .wechat,
            lengthLevel: .medium,
            emojiLevel: .light,
            scene: .pet
        )
        let context = CaptionGenerationContext(sceneTags: ["pet"], imageDescription: nil, source: .vision)
        let event = collector.makeEvent(
            caption: caption,
            action: .shareCaption,
            context: context,
            targetLanguage: .simplifiedChinese,
            isExploration: true,
            dwellSeconds: 18.37
        )

        let updated = collector.updatedPreference(from: event, current: .default)

        XCTAssertEqual(event.dwellSeconds, 18.4)
        XCTAssertGreaterThan(event.rewardScore, collector.rewardScore(for: .shareCaption))
        XCTAssertGreaterThan(updated.weight(for: "style.humor"), 0.5)
        XCTAssertGreaterThan(updated.weight(for: "scene.pet"), 0.5)
        XCTAssertGreaterThan(updated.weight(for: "length.medium"), 0.5)
        XCTAssertGreaterThan(updated.weight(for: "emoji.low"), 0.5)
    }

    func testEditedFinalCaptionFeedbackKeepsEditSummaryAndLearnsFinalTextLength() {
        let collector = FeedbackCollector()
        let original = CaptionCandidate(
            text: "今天也被这只猫治愈了。",
            style: .daily,
            platform: .wechat,
            lengthLevel: .medium,
            emojiLevel: .none,
            scene: .pet
        )
        let finalCaption = original
            .withText("猫认真吃牛排，这一幕有点太会生活。")
            .withLengthLevel(.short)
        let editSummary = CaptionEditSummary(originalText: original.text, finalText: finalCaption.text)
        let context = CaptionGenerationContext(sceneTags: ["pet"], imageDescription: nil, source: .vision)

        let event = collector.makeEvent(
            caption: finalCaption,
            action: .editedFinalCaptionUsed,
            context: context,
            targetLanguage: .simplifiedChinese,
            isExploration: false,
            dwellSeconds: 12,
            editSummary: editSummary
        )

        let updated = collector.updatedPreference(from: event, current: .default)

        XCTAssertTrue(event.editSummary?.wasEdited == true)
        XCTAssertEqual(event.editSummary?.finalText, "猫认真吃牛排，这一幕有点太会生活。")
        XCTAssertGreaterThan(event.rewardScore, collector.rewardScore(for: .shareCaption))
        XCTAssertTrue(event.features.learningKeys.contains("length.short"))
        XCTAssertGreaterThan(updated.weight(for: "scene.pet"), 0.5)
        XCTAssertGreaterThan(updated.weight(for: "length.short"), 0.5)
    }

    func testRecommendationEngineRanksByLocalPreferenceAndAddsExploration() {
        var preference = RecommendationPreferenceProfile.default
        preference.weights["style.humor"] = 0.90
        preference.weights["scene.pet"] = 0.82
        preference.weights["length.medium"] = 0.75

        let candidates = [
            CaptionCandidate(text: "这只猫今天负责把餐桌气氛炒热。", style: .humor, platform: .wechat, lengthLevel: .medium, emojiLevel: .light, scene: .pet),
            CaptionCandidate(text: "一口日常，一点可爱。", style: .daily, platform: .wechat, lengthLevel: .short, emojiLevel: .none, scene: .pet),
            CaptionCandidate(text: "餐桌边的小小治愈。", style: .healing, platform: .wechat, lengthLevel: .short, emojiLevel: .none, scene: .pet),
            CaptionCandidate(text: "温柔光线里的一餐。", style: .poetic, platform: .wechat, lengthLevel: .medium, emojiLevel: .none, scene: .pet),
            CaptionCandidate(text: "今日份可爱开饭。", style: .xiaohongshu, platform: .wechat, lengthLevel: .medium, emojiLevel: .light, scene: .pet),
            CaptionCandidate(text: "简简单单也很好。", style: .concise, platform: .wechat, lengthLevel: .short, emojiLevel: .none, scene: .pet)
        ]
        let context = CaptionGenerationContext(sceneTags: ["pet"], imageDescription: nil, source: .vision)

        let result = RecommendationEngine().recommend(
            candidates: candidates,
            context: context,
            targetPlatform: .wechat,
            preference: preference,
            recentFeedback: [],
            targetLanguage: .simplifiedChinese
        )

        XCTAssertEqual(result.rankedCaptions.count, 5)
        XCTAssertEqual(result.rankedCaptions.first?.candidate.style, .humor)
        XCTAssertEqual(result.rankedCaptions.filter(\.isExploration).count, 1)
        XCTAssertTrue(result.rankedCaptions.allSatisfy { !$0.scoreComponents.isEmpty })
    }

    func testCaptionFeatureExtractorMapsInstagramAndLanguage() {
        let caption = CaptionCandidate(
            text: "Soft light, tiny moment, saved.",
            style: .premium,
            platform: .instagram,
            lengthLevel: .short,
            emojiLevel: .none,
            scene: .daily
        )

        let features = CaptionFeatureExtractor().extract(
            from: caption,
            context: .empty,
            targetLanguage: .simplifiedChinese
        )

        XCTAssertEqual(features.style, "instagram")
        XCTAssertEqual(features.language, "en-US")
        XCTAssertTrue(features.learningKeys.contains("style.instagram"))
        XCTAssertTrue(features.learningKeys.contains("language.en"))
    }

    func testCaptionQualityEvaluatorPrefersConcreteAdultWriting() {
        let labels = [
            VisionImageLabel(name: "cat", confidence: 0.9),
            VisionImageLabel(name: "plate", confidence: 0.86),
            VisionImageLabel(name: "tableware", confidence: 0.84)
        ]
        let analysis = ImageAnalysisResult(
            visionLabels: labels,
            recognizedTexts: [],
            visualTraits: .empty,
            featureFlags: ImageFeatureFlags(
                hasPerson: false,
                hasFood: true,
                hasPet: true,
                hasStreet: false,
                hasBuilding: false,
                hasSky: false,
                hasPlant: false
            ),
            sceneResolution: SceneResolver().resolve(labels: labels)
        )
        let context = CaptionGenerationContext(analysisResult: analysis, manualScene: .auto)
        let concrete = CaptionCandidate(
            text: "这只猫把餐盘边的气氛拿捏得很认真。",
            style: .humor,
            lengthLevel: .medium,
            emojiLevel: .none,
            scene: .pet
        )
        let generic = CaptionCandidate(
            text: "这只猫咪好可爱，让人感到很温暖很幸福。",
            style: .healing,
            lengthLevel: .medium,
            emojiLevel: .none,
            scene: .pet
        )

        let evaluator = CaptionQualityEvaluator()

        XCTAssertGreaterThan(evaluator.evaluate(concrete, context: context).score, evaluator.evaluate(generic, context: context).score)
        XCTAssertEqual(evaluator.ranked([generic, concrete], context: context).first?.text, concrete.text)
    }
}

final class ShareSheetItemSourceTests: XCTestCase {
    func testTextItemSourceProvidesCaptionForWeChatShare() {
        let caption = "今天这张照片可以直接发朋友圈。"
        let captionURL = URL(fileURLWithPath: "/tmp/snapcopy-caption.txt")
        let source = SnapCopyShareTextItemSource(caption: caption, captionURL: captionURL)
        let controller = UIActivityViewController(activityItems: [caption], applicationActivities: nil)
        let wechatActivity = UIActivity.ActivityType(rawValue: "com.tencent.xin.sharetimeline")

        let item = source.activityViewController(controller, itemForActivityType: wechatActivity)

        XCTAssertEqual(item as? String, caption)
    }

    func testTextItemSourceStillUsesFileURLForSaveToFiles() {
        let captionURL = URL(fileURLWithPath: "/tmp/snapcopy-caption.txt")
        let source = SnapCopyShareTextItemSource(caption: "caption", captionURL: captionURL)
        let controller = UIActivityViewController(activityItems: ["caption"], applicationActivities: nil)
        let saveToFilesActivity = UIActivity.ActivityType(rawValue: "com.apple.DocumentManagerUICore.SaveToFiles")

        let item = source.activityViewController(controller, itemForActivityType: saveToFilesActivity)

        XCTAssertEqual(item as? URL, captionURL)
    }
}
