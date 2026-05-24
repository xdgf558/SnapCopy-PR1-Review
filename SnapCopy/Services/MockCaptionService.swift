import UIKit

final class MockCaptionService: CaptionService {
    func localAIStatus() -> LocalAIAvailabilityStatus {
        .unavailable("当前使用基础文案。")
    }

    func fallbackCandidates(context: CaptionGenerationContext) -> [CaptionCandidate] {
        let strategyCandidates = CaptionStrategyLibrary().fallbackCandidates(
            context: context,
            language: .simplifiedChinese,
            platform: .general,
            lengthLevel: .medium
        )
        if !strategyCandidates.isEmpty {
            return strategyCandidates
        }

        return makeCandidates(context: context, language: .simplifiedChinese)
    }

    func fallbackCandidates(context: CaptionGenerationContext, preference: UserPreference) -> [CaptionCandidate] {
        let preferredPlatform = preference.preferredPlatforms.first ?? .general
        let strategyCandidates = CaptionStrategyLibrary().fallbackCandidates(
            context: context,
            language: preference.preferredCaptionLanguage,
            platform: preferredPlatform,
            lengthLevel: preference.preferredLengthLevel
        )
        if !strategyCandidates.isEmpty {
            return strategyCandidates
        }

        var candidates = makeCandidates(context: context, language: preference.preferredCaptionLanguage)
            .map { $0.withLengthLevel(preference.preferredLengthLevel) }

        if let platform = preference.preferredPlatforms.first, platform != .general {
            candidates = candidates.map { candidate in
                candidate.withPlatform(platform)
            }
        }

        return candidates
    }

    func generateCaptions(
        for image: UIImage,
        context: CaptionGenerationContext,
        preference: UserPreference
    ) async throws -> CaptionGenerationResult {
        let generationPrompt = CaptionGenerationPromptBuilder().makePrompt(context: context, preference: preference)
        let preferenceSortedCandidates = PreferenceEngine().sort(
            fallbackCandidates(context: context, preference: preference),
            using: preference,
            context: context
        )
        let candidates = CaptionQualityEvaluator().ranked(preferenceSortedCandidates, context: context)

        return CaptionGenerationResult(
            candidates: candidates,
            mode: .mock,
            statusMessage: "已使用基础文案。\(contextStatusText(context))\(preferenceStatusText(preference, context: context))",
            debugInfo: CaptionGenerationDebugInfo(
                contextJSON: generationPrompt.contextJSON,
                foundationPrompt: generationPrompt.prompt,
                rawFoundationResult: "Mock fallback candidates:\n\(candidates.map(\.text).joined(separator: "\n"))"
            )
        )
    }

    private func makeCandidates(context: CaptionGenerationContext, language: CaptionLanguage) -> [CaptionCandidate] {
        if let sceneCandidates = sceneCandidates(for: context, language: language) {
            return sceneCandidates
        }

        switch language {
        case .englishUS:
            return [
                make("Keeping this moment close, just as it is.", style: .healing, scene: .daily),
                make("Life did not ask to be this photogenic, but here we are.", style: .humor, scene: .daily),
                make("Light, space, and a quiet kind of polish.", style: .premium, scene: .daily),
                make("A small daily scene worth saving.", style: .xiaohongshu, scene: .daily),
                make("Worth keeping.", style: .concise, scene: .daily)
            ]
        case .japanese:
            return [
                make("この瞬間を、そっと今日の中に残しておく。", style: .healing, scene: .daily),
                make("何気ない一枚なのに、ちょっといい感じ。", style: .humor, scene: .daily),
                make("光と余白が、今日を静かに整えてくれる。", style: .premium, scene: .daily),
                make("今日の小さな記録。ちょうどいい日常感。", style: .xiaohongshu, scene: .daily),
                make("残しておきたい瞬間。", style: .concise, scene: .daily)
            ]
        case .traditionalChinese:
            return [
                make("把這一刻收進口袋，今天也有一點溫柔值得記住。", style: .healing, scene: .daily),
                make("生活偶爾不講道理，但這一張先贏了。", style: .humor, scene: .daily),
                make("光影、留白和當下，剛好組成今天的質感。", style: .premium, scene: .daily),
                make("今日份小確幸，簡單記錄一下這段剛剛好的日常。", style: .xiaohongshu, scene: .daily),
                make("這一刻，值得留下。", style: .concise, scene: .daily)
            ]
        case .simplifiedChinese:
            return [
                CaptionCandidate(
                    id: UUID(uuidString: "A45E53C7-89D7-4F03-8FF8-B86406F1496B") ?? UUID(),
                    text: "把这一刻收进口袋，今天也有一点温柔值得记住。",
                    style: .healing,
                    platform: .wechat,
                    lengthLevel: .medium,
                    emojiLevel: .none,
                    scene: .daily
                ),
                CaptionCandidate(
                    id: UUID(uuidString: "D7DB4F3C-6F7A-4394-AB75-E06497A8F8E9") ?? UUID(),
                    text: "生活偶尔不讲道理，但这一张先赢了。",
                    style: .humor,
                    platform: .general,
                    lengthLevel: .short,
                    emojiLevel: .none,
                    scene: .daily
                ),
                CaptionCandidate(
                    id: UUID(uuidString: "58FD6731-B686-48E5-B095-21F94F19F90F") ?? UUID(),
                    text: "光影、留白和当下，刚好组成今天的质感。",
                    style: .premium,
                    platform: .instagram,
                    lengthLevel: .medium,
                    emojiLevel: .none,
                    scene: .daily
                ),
                CaptionCandidate(
                    id: UUID(uuidString: "F5243D4C-C07B-4BE5-938B-A7D4287D8C65") ?? UUID(),
                    text: "今日份小确幸，简单记录一下这段刚刚好的日常。",
                    style: .xiaohongshu,
                    platform: .xiaohongshu,
                    lengthLevel: .medium,
                    emojiLevel: .light,
                    scene: .daily
                ),
                CaptionCandidate(
                    id: UUID(uuidString: "DC631207-FC6D-45DC-A6D7-A98F8DA12D1F") ?? UUID(),
                    text: "这一刻，值得留下。",
                    style: .concise,
                    platform: .general,
                    lengthLevel: .short,
                    emojiLevel: .none,
                    scene: .daily
                )
            ]
        }
    }

    private func sceneCandidates(for context: CaptionGenerationContext, language: CaptionLanguage) -> [CaptionCandidate]? {
        let scene = context.primaryScene

        switch language {
        case .englishUS:
            return englishSceneCandidates(for: scene)
        case .japanese:
            return japaneseSceneCandidates(for: scene)
        case .traditionalChinese:
            return traditionalChineseSceneCandidates(for: scene)
        case .simplifiedChinese:
            return simplifiedChineseSceneCandidates(for: scene)
        }
    }

    private func simplifiedChineseSceneCandidates(for scene: SceneType) -> [CaptionCandidate]? {
        switch scene {
        case .breakfast, .cafe:
            return simplifiedChineseSceneCandidates(for: .food)
        case .walking, .sunset:
            return simplifiedChineseSceneCandidates(for: .street)
        case .outfit, .fitness, .home:
            return nil
        case .food:
            return [
                make("把这一口日常拍下来，今天的快乐有了具体形状。", style: .healing, scene: .food),
                make("认真吃饭，也是在认真给生活充电。", style: .xiaohongshu, scene: .food),
                make("这一刻先不赶路，先好好享受。", style: .premium, scene: .food),
                make("嘴角和胃，总要有一个先被治愈。", style: .humor, scene: .food),
                make("今日份满足。", style: .concise, scene: .food)
            ]
        case .pet:
            return [
                make("有些陪伴不用说话，光是出现就很治愈。", style: .healing, scene: .pet),
                make("今日份可爱已超标，批准收藏。", style: .humor, scene: .pet),
                make("把柔软的一刻留给今天。", style: .premium, scene: .pet),
                make("被小可爱治愈的一天，值得记录。", style: .xiaohongshu, scene: .pet),
                make("可爱在线。", style: .concise, scene: .pet)
            ]
        case .travel:
            return [
                make("把路上的风景收进相册，也收进今天的心情。", style: .healing, scene: .travel),
                make("出门一趟，连空气都换了滤镜。", style: .humor, scene: .travel),
                make("在新的坐标里，慢慢找回松弛感。", style: .premium, scene: .travel),
                make("今日份出逃成功，风景和心情都刚好。", style: .xiaohongshu, scene: .travel),
                make("在路上。", style: .concise, scene: .travel)
            ]
        case .street:
            return [
                make("路过的街角，也有值得停下来的光。", style: .healing, scene: .street),
                make("今天的城市随机掉落了一点好看。", style: .humor, scene: .street),
                make("日常的边角，也能拍出自己的节奏。", style: .premium, scene: .street),
                make("随手记录一下，今天的街景很会。", style: .xiaohongshu, scene: .street),
                make("街角片刻。", style: .concise, scene: .street)
            ]
        case .work:
            return [
                make("把认真生活的样子，也留在今天。", style: .healing, scene: .work),
                make("努力营业中，灵感偶尔在线。", style: .humor, scene: .work),
                make("专注，是今天最安静的质感。", style: .premium, scene: .work),
                make("今日份自律打卡，慢慢变好也很值得。", style: .xiaohongshu, scene: .work),
                make("继续向前。", style: .concise, scene: .work)
            ]
        case .daily, .unknown:
            return nil
        }
    }

    private func traditionalChineseSceneCandidates(for scene: SceneType) -> [CaptionCandidate]? {
        switch scene {
        case .breakfast, .cafe:
            return traditionalChineseSceneCandidates(for: .food)
        case .walking, .sunset:
            return traditionalChineseSceneCandidates(for: .street)
        case .outfit, .fitness, .home:
            return nil
        case .food:
            return [
                make("把這一口日常拍下來，今天的快樂有了具體形狀。", style: .healing, scene: .food),
                make("認真吃飯，也是在認真給生活充電。", style: .xiaohongshu, scene: .food),
                make("這一刻先不趕路，先好好享受。", style: .premium, scene: .food),
                make("嘴角和胃，總要有一個先被治癒。", style: .humor, scene: .food),
                make("今日份滿足。", style: .concise, scene: .food)
            ]
        case .pet:
            return [
                make("有些陪伴不用說話，光是出現就很治癒。", style: .healing, scene: .pet),
                make("今日份可愛已超標，批准收藏。", style: .humor, scene: .pet),
                make("把柔軟的一刻留給今天。", style: .premium, scene: .pet),
                make("被小可愛治癒的一天，值得記錄。", style: .xiaohongshu, scene: .pet),
                make("可愛在線。", style: .concise, scene: .pet)
            ]
        case .travel:
            return [
                make("把路上的風景收進相簿，也收進今天的心情。", style: .healing, scene: .travel),
                make("出門一趟，連空氣都換了濾鏡。", style: .humor, scene: .travel),
                make("在新的座標裡，慢慢找回鬆弛感。", style: .premium, scene: .travel),
                make("今日份出逃成功，風景和心情都剛好。", style: .xiaohongshu, scene: .travel),
                make("在路上。", style: .concise, scene: .travel)
            ]
        case .street:
            return [
                make("路過的街角，也有值得停下來的光。", style: .healing, scene: .street),
                make("今天的城市隨機掉落了一點好看。", style: .humor, scene: .street),
                make("日常的邊角，也能拍出自己的節奏。", style: .premium, scene: .street),
                make("隨手記錄一下，今天的街景很會。", style: .xiaohongshu, scene: .street),
                make("街角片刻。", style: .concise, scene: .street)
            ]
        case .work:
            return [
                make("把認真生活的樣子，也留在今天。", style: .healing, scene: .work),
                make("努力營業中，靈感偶爾在線。", style: .humor, scene: .work),
                make("專注，是今天最安靜的質感。", style: .premium, scene: .work),
                make("今日份自律打卡，慢慢變好也很值得。", style: .xiaohongshu, scene: .work),
                make("繼續向前。", style: .concise, scene: .work)
            ]
        case .daily, .unknown:
            return nil
        }
    }

    private func englishSceneCandidates(for scene: SceneType) -> [CaptionCandidate]? {
        switch scene {
        case .breakfast, .cafe:
            return englishSceneCandidates(for: .food)
        case .walking, .sunset:
            return englishSceneCandidates(for: .street)
        case .outfit, .fitness, .home:
            return nil
        case .food:
            return [
                make("A small bite of today, saved properly.", style: .healing, scene: .food),
                make("Taking food seriously, for emotional support reasons.", style: .humor, scene: .food),
                make("Simple flavors, clean light, quiet luxury.", style: .premium, scene: .food),
                make("Today's little treat, documented.", style: .xiaohongshu, scene: .food),
                make("Worth the pause.", style: .concise, scene: .food)
            ]
        case .pet:
            return [
                make("Some company says everything without saying a word.", style: .healing, scene: .pet),
                make("Today's cuteness limit has officially been exceeded.", style: .humor, scene: .pet),
                make("A soft little moment for the day.", style: .premium, scene: .pet),
                make("A tiny dose of joy, perfectly timed.", style: .xiaohongshu, scene: .pet),
                make("Cuteness, confirmed.", style: .concise, scene: .pet)
            ]
        case .travel:
            return [
                make("Saving the view, and a little bit of how it felt.", style: .healing, scene: .travel),
                make("Left the house and somehow the air got a filter.", style: .humor, scene: .travel),
                make("A new coordinate, a softer pace.", style: .premium, scene: .travel),
                make("A tiny escape, right on time.", style: .xiaohongshu, scene: .travel),
                make("On the way.", style: .concise, scene: .travel)
            ]
        case .street:
            return [
                make("A corner worth slowing down for.", style: .healing, scene: .street),
                make("The city casually decided to look good today.", style: .humor, scene: .street),
                make("Everyday edges, photographed with rhythm.", style: .premium, scene: .street),
                make("A quick city note from today.", style: .xiaohongshu, scene: .street),
                make("Street moment.", style: .concise, scene: .street)
            ]
        case .work:
            return [
                make("A quiet little proof of showing up.", style: .healing, scene: .work),
                make("Currently operating on focus and questionable inspiration.", style: .humor, scene: .work),
                make("Focus, but make it calm.", style: .premium, scene: .work),
                make("Today's work mode, gently documented.", style: .xiaohongshu, scene: .work),
                make("Keep going.", style: .concise, scene: .work)
            ]
        case .daily, .unknown:
            return nil
        }
    }

    private func japaneseSceneCandidates(for scene: SceneType) -> [CaptionCandidate]? {
        switch scene {
        case .breakfast, .cafe:
            return japaneseSceneCandidates(for: .food)
        case .walking, .sunset:
            return japaneseSceneCandidates(for: .street)
        case .outfit, .fitness, .home:
            return nil
        case .food:
            return [
                make("今日の小さなおいしい時間を、ちゃんと残しておく。", style: .healing, scene: .food),
                make("お腹も気分も、先に満たしておく日。", style: .humor, scene: .food),
                make("シンプルなのに、静かに整っている一皿。", style: .premium, scene: .food),
                make("今日のごほうび、しっかり記録。", style: .xiaohongshu, scene: .food),
                make("満たされた。", style: .concise, scene: .food)
            ]
        case .pet:
            return [
                make("言葉はいらないくらい、そばにいるだけで癒やされる。", style: .healing, scene: .pet),
                make("本日のかわいい、すでに定員オーバー。", style: .humor, scene: .pet),
                make("やわらかい一瞬を、今日に残す。", style: .premium, scene: .pet),
                make("小さなかわいさに救われた日。", style: .xiaohongshu, scene: .pet),
                make("かわいい確認。", style: .concise, scene: .pet)
            ]
        case .travel:
            return [
                make("景色だけじゃなく、その時の気分も持ち帰る。", style: .healing, scene: .travel),
                make("外に出たら、空気まで少し違って見えた。", style: .humor, scene: .travel),
                make("新しい場所で、少しだけ呼吸が深くなる。", style: .premium, scene: .travel),
                make("今日の小さな逃避、成功。", style: .xiaohongshu, scene: .travel),
                make("移動中。", style: .concise, scene: .travel)
            ]
        case .street:
            return [
                make("通り過ぎるだけでは惜しい、街の一角。", style: .healing, scene: .street),
                make("今日の街、さりげなく盛れている。", style: .humor, scene: .street),
                make("日常の端に、静かなリズムがある。", style: .premium, scene: .street),
                make("今日の街角メモ。", style: .xiaohongshu, scene: .street),
                make("街角の一瞬。", style: .concise, scene: .street)
            ]
        case .work:
            return [
                make("ちゃんと向き合った時間も、今日の記録に。", style: .healing, scene: .work),
                make("集中力、たまに在席しています。", style: .humor, scene: .work),
                make("静かな集中が、今日の質感。", style: .premium, scene: .work),
                make("今日の作業モード、少しずつ前へ。", style: .xiaohongshu, scene: .work),
                make("続けていく。", style: .concise, scene: .work)
            ]
        case .daily, .unknown:
            return nil
        }
    }

    private func make(_ text: String, style: CaptionStyle, scene: SceneType) -> CaptionCandidate {
        CaptionCandidate(
            text: text,
            style: style,
            platform: style == .xiaohongshu ? .xiaohongshu : .general,
            lengthLevel: text.count > 18 ? .medium : .short,
            emojiLevel: .none,
            scene: scene
        )
    }

    private func contextStatusText(_ context: CaptionGenerationContext) -> String {
        var parts: [String] = []

        if !context.sceneTags.isEmpty {
            parts.append("场景标签：\(context.sceneTags.joined(separator: "、"))")
        }

        if context.hasImageDetails {
            parts.append("已传入图片细节")
        }

        guard !parts.isEmpty else {
            return ""
        }

        return " \(parts.joined(separator: "；"))。"
    }

    private func preferenceStatusText(_ preference: UserPreference, context: CaptionGenerationContext) -> String {
        if preference.hasSceneSpecificGenerationPreference(for: context), preference.hasTextGenerationPreference {
            return " 已参考这个场景下的评分偏好和词句偏好。"
        }

        if preference.hasSceneSpecificGenerationPreference(for: context) {
            return " 已参考这个场景下的评分偏好。"
        }

        if preference.hasTextGenerationPreference {
            return " 已参考你的词句偏好。"
        }

        return preference.hasLearnedGenerationPreference ? " 已参考你的评分偏好。" : ""
    }
}
