import XCTest
import UIKit
@testable import SnapCopy

final class PreferenceEngineTests: XCTestCase {
    func testHighRatingIncreasesStyleWeight() {
        let engine = PreferenceEngine()
        var preference = UserPreference.default
        preference.styleWeights[.healing] = 0.5

        let event = RatingEvent(
            captionId: UUID(),
            rating: 5,
            styleTags: [.healing],
            sceneTags: [],
            platformHints: [.general]
        )

        let updatedPreference = engine.updatePreference(from: event, current: preference)

        XCTAssertEqual(updatedPreference.styleWeights[.healing] ?? 0, 0.62, accuracy: 0.0001)
    }

    func testLowRatingDecreasesStyleWeight() {
        let engine = PreferenceEngine()
        var preference = UserPreference.default
        preference.styleWeights[.humor] = 0.5

        let event = RatingEvent(
            captionId: UUID(),
            rating: 1,
            styleTags: [.humor],
            sceneTags: [],
            platformHints: [.general]
        )

        let updatedPreference = engine.updatePreference(from: event, current: preference)

        XCTAssertEqual(updatedPreference.styleWeights[.humor] ?? 0, 0.38, accuracy: 0.0001)
    }

    func testWeightIsClampedBetweenZeroAndOne() {
        let engine = PreferenceEngine()
        var preference = UserPreference.default
        preference.styleWeights[.premium] = 0.96

        let event = RatingEvent(
            captionId: UUID(),
            rating: 5,
            styleTags: [.premium],
            sceneTags: [],
            platformHints: [.general]
        )

        let updatedPreference = engine.updatePreference(from: event, current: preference)

        XCTAssertEqual(updatedPreference.styleWeights[.premium] ?? 0, 1.0, accuracy: 0.0001)
    }

    func testSortUsesHigherStyleWeightFirst() {
        let engine = PreferenceEngine()
        var preference = UserPreference.default
        preference.styleWeights[.healing] = 0.9
        preference.styleWeights[.humor] = 0.2

        let captions = [
            CaptionCandidate(
                text: "A",
                style: .humor,
                lengthLevel: .short,
                emojiLevel: .none
            ),
            CaptionCandidate(
                text: "B",
                style: .healing,
                lengthLevel: .short,
                emojiLevel: .none
            )
        ]

        let sortedCaptions = engine.sort(captions, using: preference)

        XCTAssertEqual(sortedCaptions.first?.style, .healing)
    }

    func testHighRatingIncreasesSceneSpecificStyleWeight() {
        let engine = PreferenceEngine()
        let preference = UserPreference.default

        let event = RatingEvent(
            captionId: UUID(),
            rating: 5,
            styleTags: [.premium],
            sceneTags: ["coffee", "food"],
            platformHints: [.general]
        )

        let updatedPreference = engine.updatePreference(from: event, current: preference)

        XCTAssertEqual(updatedPreference.styleWeights[.premium] ?? 0, 0.62, accuracy: 0.0001)
        XCTAssertEqual(updatedPreference.sceneStyleWeights["coffee"]?[.premium] ?? 0, 0.62, accuracy: 0.0001)
        XCTAssertEqual(updatedPreference.sceneStyleWeights["food"]?[.premium] ?? 0, 0.62, accuracy: 0.0001)
    }

    func testHighRatingLearnsLikedPhraseAndShortCaptionShape() {
        let engine = PreferenceEngine()
        let preference = UserPreference.default

        let event = RatingEvent(
            captionId: UUID(),
            captionText: "今日份小确幸。",
            rating: 5,
            styleTags: [.daily],
            sceneTags: ["daily"],
            platformHints: [.general]
        )

        let updatedPreference = engine.updatePreference(from: event, current: preference)

        XCTAssertEqual(updatedPreference.textPreference.phraseWeights["今日份"] ?? 0, 0.62, accuracy: 0.0001)
        XCTAssertEqual(updatedPreference.textPreference.phraseWeights["小确幸"] ?? 0, 0.62, accuracy: 0.0001)
        XCTAssertEqual(updatedPreference.textPreference.shortCaptionWeight, 0.62, accuracy: 0.0001)
    }

    func testLowRatingLearnsAvoidedPhraseAndExcitedPunctuation() {
        let engine = PreferenceEngine()
        let preference = UserPreference.default

        let event = RatingEvent(
            captionId: UUID(),
            captionText: "今天也要好好生活！✨",
            rating: 1,
            styleTags: [.xiaohongshu],
            sceneTags: ["daily"],
            platformHints: [.general]
        )

        let updatedPreference = engine.updatePreference(from: event, current: preference)

        XCTAssertEqual(updatedPreference.textPreference.phraseWeights["今天也要"] ?? 0, 0.38, accuracy: 0.0001)
        XCTAssertEqual(updatedPreference.textPreference.emojiWeight, 0.38, accuracy: 0.0001)
        XCTAssertEqual(updatedPreference.textPreference.exclamationWeight, 0.38, accuracy: 0.0001)
        XCTAssertTrue(updatedPreference.dislikedPhrases.contains("今天也要"))
    }

    func testSceneSpecificSortCanOutrankGlobalWeight() {
        let engine = PreferenceEngine()
        var preference = UserPreference.default
        preference.styleWeights[.humor] = 0.9
        preference.styleWeights[.healing] = 0.5
        preference.sceneStyleWeights["food"] = [
            .humor: 0.5,
            .healing: 0.9
        ]

        let context = CaptionGenerationContext(
            sceneTags: ["food"],
            imageDescription: nil,
            source: .vision
        )
        let captions = [
            CaptionCandidate(
                text: "A",
                style: .humor,
                lengthLevel: .short,
                emojiLevel: .none,
                scene: .food
            ),
            CaptionCandidate(
                text: "B",
                style: .healing,
                lengthLevel: .short,
                emojiLevel: .none,
                scene: .food
            )
        ]

        let sortedCaptions = engine.sort(captions, using: preference, context: context)

        XCTAssertEqual(sortedCaptions.first?.style, .healing)
    }

    func testTextPreferenceSortCanNudgeEqualStyleCaptions() {
        let engine = PreferenceEngine()
        var preference = UserPreference.default
        preference.textPreference.phraseWeights["生活感"] = 0.9
        preference.textPreference.phraseWeights["今天也要"] = 0.2

        let captions = [
            CaptionCandidate(
                text: "今天也要认真生活。",
                style: .daily,
                lengthLevel: .short,
                emojiLevel: .none
            ),
            CaptionCandidate(
                text: "多一点生活感，刚刚好。",
                style: .daily,
                lengthLevel: .short,
                emojiLevel: .none
            )
        ]

        let sortedCaptions = engine.sort(captions, using: preference)

        XCTAssertEqual(sortedCaptions.first?.text, "多一点生活感，刚刚好。")
    }

    func testCaptionDeduplicatorRemovesRepeatedTextAndFillsFallbacks() {
        let deduplicator = CaptionCandidateDeduplicator()
        let generated = [
            CaptionCandidate(
                text: "这一刻，值得留下。",
                style: .healing,
                lengthLevel: .short,
                emojiLevel: .none
            ),
            CaptionCandidate(
                text: "这一刻值得留下",
                style: .humor,
                lengthLevel: .short,
                emojiLevel: .none
            )
        ]
        let fallbacks = [
            CaptionCandidate(
                text: "生活偶尔不讲道理，但这一张先赢了。",
                style: .humor,
                lengthLevel: .medium,
                emojiLevel: .none
            ),
            CaptionCandidate(
                text: "光影、留白和当下，刚好组成今天的质感。",
                style: .premium,
                lengthLevel: .medium,
                emojiLevel: .none
            )
        ]

        let uniqueCaptions = deduplicator.uniqueCandidates(generated, fallbackCandidates: fallbacks)

        XCTAssertEqual(uniqueCaptions.map(\.text), [
            "这一刻，值得留下。",
            "生活偶尔不讲道理，但这一张先赢了。",
            "光影、留白和当下，刚好组成今天的质感。"
        ])
    }

    func testPreferencePromptIncludesLikedStyles() {
        var preference = UserPreference.default
        preference.styleWeights[.premium] = 0.74

        XCTAssertTrue(preference.hasLearnedGenerationPreference)
        XCTAssertTrue(preference.generationPromptSummary.contains("premium"))
        XCTAssertTrue(preference.generationPromptSummary.contains("likedStyles"))
    }

    func testPreferencePromptIncludesAvoidStyles() {
        var preference = UserPreference.default
        preference.styleWeights[.humor] = 0.32

        XCTAssertTrue(preference.hasLearnedGenerationPreference)
        XCTAssertTrue(preference.generationPromptSummary.contains("humor"))
        XCTAssertTrue(preference.generationPromptSummary.contains("avoidStyles"))
    }

    func testPreferencePromptIncludesSceneSpecificStyles() {
        var preference = UserPreference.default
        preference.sceneStyleWeights["pet"] = [
            .humor: 0.74,
            .premium: 0.32
        ]
        let context = CaptionGenerationContext(
            sceneTags: ["pet"],
            imageDescription: nil,
            source: .vision
        )

        let summary = preference.generationPromptSummary(for: context)

        XCTAssertTrue(preference.hasSceneSpecificGenerationPreference(for: context))
        XCTAssertTrue(summary.contains("sceneLikedStyles"))
        XCTAssertTrue(summary.contains("humor"))
        XCTAssertTrue(summary.contains("sceneAvoidStyles"))
        XCTAssertTrue(summary.contains("premium"))
    }

    func testPreferencePromptIncludesTextPreferences() {
        var preference = UserPreference.default
        preference.textPreference.phraseWeights["生活感"] = 0.74
        preference.textPreference.phraseWeights["今天也要"] = 0.32
        preference.textPreference.shortCaptionWeight = 0.74
        preference.textPreference.emojiWeight = 0.32
        preference.textPreference.exclamationWeight = 0.32

        let summary = preference.generationPromptSummary

        XCTAssertTrue(preference.hasTextGenerationPreference)
        XCTAssertTrue(summary.contains("likedPhrases"))
        XCTAssertTrue(summary.contains("生活感"))
        XCTAssertTrue(summary.contains("avoidPhrases"))
        XCTAssertTrue(summary.contains("今天也要"))
        XCTAssertTrue(summary.contains("sentenceShape"))
        XCTAssertTrue(summary.contains("emojiPreference"))
        XCTAssertTrue(summary.contains("punctuationPreference"))
    }

    func testPreferenceStoresPreferredCaptionLanguage() {
        var preference = UserPreference.default

        preference.setPreferredCaptionLanguage(.englishUS)

        XCTAssertEqual(preference.preferredLanguages, ["en-US"])
        XCTAssertEqual(preference.preferredCaptionLanguage, .englishUS)
        XCTAssertTrue(preference.generationPromptSummary.contains("preferredLanguages: en-US"))
    }

    func testPreferenceStoresPreferredPlatform() {
        var preference = UserPreference.default

        preference.setPreferredPlatforms([.wechat])

        XCTAssertEqual(preference.preferredPlatforms, [.wechat])
        XCTAssertTrue(preference.generationPromptSummary.contains("preferredPlatforms: wechat"))
    }

    func testPreferenceStoresPreferredLengthLevel() {
        var preference = UserPreference.default

        preference.setPreferredLengthLevel(.long)

        XCTAssertEqual(preference.preferredLengthLevel, .long)
        XCTAssertTrue(preference.generationPromptSummary.contains("preferredLengthLevel: long"))
    }

    func testGenerationPromptIncludesPlatformTemplate() {
        var preference = UserPreference.default
        preference.setPreferredPlatforms([.wechat])
        preference.setPreferredLengthLevel(.long)

        let prompt = CaptionGenerationPromptBuilder().makePrompt(context: .empty, preference: preference)

        XCTAssertTrue(prompt.prompt.contains("WeChat Moments"))
        XCTAssertTrue(prompt.contextJSON.contains("\"platform\" : \"wechat\""))
        XCTAssertTrue(prompt.contextJSON.contains("\"lengthLevel\" : \"long\""))
        XCTAssertTrue(prompt.prompt.contains("Detailed"))
        XCTAssertTrue(prompt.prompt.contains("lengthLevel field to \"long\""))
    }

    func testCaptionContextBuilderIgnoresOverbroadAvoidStyles() {
        var preference = UserPreference.default
        for style in CaptionStyle.allCases {
            preference.styleWeights[style] = 0.32
        }

        let payload = CaptionContextBuilder().build(context: .empty, preference: preference)

        XCTAssertTrue(payload.generation.avoidStyles.isEmpty)
        XCTAssertNotNil(payload.generation.stylePreferenceWarning)
        XCTAssertTrue(payload.generation.stylePreferenceWarning?.contains("ignored") == true)
    }

    func testMockCaptionServiceUsesPreferredLanguage() {
        var preference = UserPreference.default
        preference.setPreferredCaptionLanguage(.englishUS)

        let candidates = MockCaptionService().fallbackCandidates(
            context: .empty,
            preference: preference
        )

        XCTAssertEqual(candidates.first?.text, "Keeping this moment close, just as it is.")
        XCTAssertFalse(candidates.contains { $0.text.contains("这一刻") })
    }

    func testCaptionHistoryStoreSavesGeneratedCandidatesAndFavorites() {
        let suiteName = "CaptionHistoryStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = CaptionHistoryStore(userDefaults: defaults)
        let caption = CaptionCandidate(
            text: "今天的光刚刚好。",
            style: .daily,
            lengthLevel: .medium,
            emojiLevel: .light
        )

        store.saveGeneratedCandidates([caption], image: nil)

        XCTAssertEqual(store.loadItems().count, 1)
        XCTAssertEqual(store.loadItems().first?.caption.text, caption.text)
        XCTAssertFalse(store.loadItems().first?.isFavorite ?? true)

        XCTAssertTrue(store.toggleFavorite(for: caption, image: nil))
        XCTAssertTrue(store.favoriteCaptionKeys().contains(CaptionHistoryStore.key(for: caption.text)))
        XCTAssertTrue(store.loadItems().first?.isFavorite ?? false)

        XCTAssertFalse(store.toggleFavorite(for: caption, image: nil))
        XCTAssertFalse(store.favoriteCaptionKeys().contains(CaptionHistoryStore.key(for: caption.text)))

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testCaptionHistoryStoreRecordsInteractionWithoutDuplicatingCaption() {
        let suiteName = "CaptionHistoryStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = CaptionHistoryStore(userDefaults: defaults)
        let caption = CaptionCandidate(
            text: "一杯咖啡，给今天一点慢下来的理由。",
            style: .healing,
            platform: .xiaohongshu,
            lengthLevel: .long,
            emojiLevel: .none,
            scene: .daily
        )

        store.saveGeneratedCandidates([caption], image: nil)
        store.recordInteraction(for: caption, image: nil, interaction: .copied)

        let items = store.loadItems()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.lastInteraction, .copied)
        XCTAssertEqual(items.first?.caption.platform, .xiaohongshu)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testCaptionHistoryStorePrunesExpiredUnfavoritedHistoryOnly() throws {
        let suiteName = "CaptionHistoryStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(1, forKey: "snapcopy.captionHistoryAutoDeleteDays")
        let store = CaptionHistoryStore(userDefaults: defaults)
        let oldDate = Date().addingTimeInterval(-3 * 24 * 60 * 60)
        let recentDate = Date().addingTimeInterval(-2 * 60 * 60)
        let oldUnfavorited = CaptionHistoryItem(
            caption: CaptionCandidate(text: "旧文案", style: .daily, lengthLevel: .medium, emojiLevel: .none),
            createdAt: oldDate,
            lastUpdatedAt: oldDate,
            isFavorite: false
        )
        let oldFavorite = CaptionHistoryItem(
            caption: CaptionCandidate(text: "收藏文案", style: .healing, lengthLevel: .medium, emojiLevel: .light),
            createdAt: oldDate,
            lastUpdatedAt: oldDate,
            isFavorite: true
        )
        let recentUnfavorited = CaptionHistoryItem(
            caption: CaptionCandidate(text: "最近文案", style: .premium, lengthLevel: .short, emojiLevel: .none),
            createdAt: recentDate,
            lastUpdatedAt: recentDate,
            isFavorite: false
        )

        let data = try JSONEncoder().encode([oldUnfavorited, oldFavorite, recentUnfavorited])
        defaults.set(data, forKey: "snapcopy.captionHistoryItems")

        let items = store.loadItems()
        XCTAssertEqual(items.count, 2)
        XCTAssertFalse(items.contains { $0.caption.text == oldUnfavorited.caption.text })
        XCTAssertTrue(items.contains { $0.caption.text == oldFavorite.caption.text })
        XCTAssertTrue(items.contains { $0.caption.text == recentUnfavorited.caption.text })

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testCaptionHistoryStoreDeleteHistoryKeepsFavorites() throws {
        let suiteName = "CaptionHistoryStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = CaptionHistoryStore(userDefaults: defaults)
        let favorite = CaptionHistoryItem(
            caption: CaptionCandidate(text: "留下来的收藏", style: .healing, lengthLevel: .medium, emojiLevel: .light),
            isFavorite: true
        )
        let unfavorited = CaptionHistoryItem(
            caption: CaptionCandidate(text: "要清理的历史", style: .daily, lengthLevel: .medium, emojiLevel: .none),
            isFavorite: false
        )

        let data = try JSONEncoder().encode([favorite, unfavorited])
        defaults.set(data, forKey: "snapcopy.captionHistoryItems")

        let deletedCount = store.deleteHistoryItems(keepFavorites: true)
        let items = store.loadItems()
        XCTAssertEqual(deletedCount, 1)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.caption.text, favorite.caption.text)
        XCTAssertTrue(items.first?.isFavorite ?? false)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testCreativeImageStylePromptUsesPhotoContext() {
        let context = CaptionGenerationContext(
            sceneTags: ["pet", "daily"],
            imageDescription: "Vision labels: cat, chair. Visual traits: warm tone.",
            source: .vision
        )

        let prompt = CreativeImageStyle.xiaohongshuSticker.prompt(context: context)

        XCTAssertTrue(prompt.contains("cute lifestyle sticker"))
        XCTAssertTrue(prompt.contains("pet, daily"))
        XCTAssertTrue(prompt.contains("cat, chair"))
    }

    func testCreativeImageStylePromptRemovesUnsupportedLanguageText() {
        let context = CaptionGenerationContext(
            sceneTags: ["pet", "日常"],
            imageDescription: """
            Visible text OCR: 今天真好
            Vision labels: cat, chair
            Visual traits: 暖色, warm tone
            """,
            source: .vision
        )

        let prompt = CreativeImageStyle.cover.prompt(context: context)

        XCTAssertTrue(prompt.unicodeScalars.allSatisfy { $0.isASCII })
        XCTAssertFalse(prompt.contains("今天真好"))
        XCTAssertFalse(prompt.contains("日常"))
        XCTAssertFalse(prompt.contains("暖色"))
        XCTAssertFalse(prompt.contains("Visible text OCR"))
        XCTAssertTrue(prompt.contains("cat, chair"))
        XCTAssertTrue(prompt.contains("warm tone"))
    }

    func testCloudCreativeImageServiceIsReservedButNotConfigured() {
        let service = CloudCreativeImageService()

        XCTAssertFalse(service.isConfigured)
    }

    func testCreativeImageErrorInspectorDetectsWrappedUnsupportedLanguageError() {
        let error = NSError(
            domain: "ImagePlayground",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey: "Image generation failed with error: ImagePlayground.ImageCreator.Error.unsupportedLanguage"
            ]
        )

        XCTAssertTrue(CreativeImageErrorInspector.isUnsupportedLanguage(error))
    }

    @MainActor
    func testLocalCreativeImageFallbackRendersShareImage() {
        let sourceImage = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 90)).image { context in
            UIColor.systemPink.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 120, height: 90))
        }

        let result = LocalCreativeImageRenderer().render(sourceImage, style: .cover)

        XCTAssertEqual(result.size.width, 1080)
        XCTAssertEqual(result.size.height, 1350)
    }

    @MainActor
    func testShareCardRendererRendersCaptionCardWithoutChangingCaption() {
        let sourceImage = UIGraphicsImageRenderer(size: CGSize(width: 160, height: 120)).image { context in
            UIColor.systemTeal.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 160, height: 120))
        }
        let caption = "今天这张照片可以直接发朋友圈，不用担心文字丢失。"

        let result = ShareCardRenderer().render(image: sourceImage, caption: caption)

        XCTAssertEqual(result.size.width, 1080)
        XCTAssertGreaterThanOrEqual(result.size.height, 1350)
        XCTAssertNotNil(result.cgImage)
    }

    func testGenerationPromptIncludesCaptionStrategyLibrary() {
        let context = CaptionGenerationContext(
            sceneTags: ["pet", "food"],
            imageDescription: "cat near a dining table",
            source: .vision
        )

        let prompt = CaptionGenerationPromptBuilder().makePrompt(context: context, preference: .default)

        XCTAssertTrue(prompt.prompt.contains("Caption strategy library"))
        XCTAssertTrue(prompt.prompt.contains("pet / companion detail"))
        XCTAssertTrue(prompt.prompt.contains("好可爱"))
        XCTAssertTrue(prompt.prompt.contains("Use Caption strategy library examples as writing references"))
    }

    func testCaptionSampleLibraryKeepsGoodEditedSharedCaption() {
        let suiteName = "CaptionSampleLibraryStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = CaptionSampleLibraryStore(userDefaults: defaults)
        let context = CaptionGenerationContext(
            sceneTags: ["pet"],
            imageDescription: "cat sitting in a room",
            source: .vision
        )
        let original = CaptionCandidate(
            text: "这只猫好可爱，很治愈。",
            style: .healing,
            platform: .wechat,
            lengthLevel: .medium,
            emojiLevel: .none,
            scene: .pet
        )
        let final = original.withText("它把椅子坐成自己的领地，人类只负责安静路过。")

        let decision = store.recordSharedCaption(
            original: original,
            finalCaption: final,
            context: context,
            preference: .default,
            editSummary: CaptionEditSummary(originalText: original.text, finalText: final.text)
        )

        XCTAssertEqual(decision.action, .kept)
        XCTAssertEqual(store.loadSamples().count, 1)
        XCTAssertEqual(
            store.topSamples(for: context, language: .simplifiedChinese, platform: .wechat, limit: 1).first?.text,
            final.text
        )

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testCaptionSampleLibraryRejectsMetadataLikeCaption() {
        let suiteName = "CaptionSampleLibraryStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = CaptionSampleLibraryStore(userDefaults: defaults)
        let context = CaptionGenerationContext(
            sceneTags: ["pet"],
            imageDescription: "cat in low light",
            source: .vision
        )
        let caption = CaptionCandidate(
            text: "在这低光下，这只小猫正在享受它的晚餐。 premium instagram medium none pet",
            style: .premium,
            platform: .instagram,
            lengthLevel: .medium,
            emojiLevel: .none,
            scene: .pet
        )

        let decision = store.recordSharedCaption(
            original: caption,
            finalCaption: caption,
            context: context,
            preference: .default,
            editSummary: nil
        )

        XCTAssertEqual(decision.action, .rejected)
        XCTAssertTrue(store.loadSamples().isEmpty)

        defaults.removePersistentDomain(forName: suiteName)
    }
}
