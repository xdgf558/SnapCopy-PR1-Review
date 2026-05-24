import Foundation

struct CaptionStrategyLibrary {
    func profile(for context: CaptionGenerationContext) -> CaptionStrategyProfile {
        profile(for: resolvedScene(for: context))
    }

    func profile(for scene: SceneType) -> CaptionStrategyProfile {
        switch scene {
        case .breakfast:
            return CaptionStrategyProfile(
                scene: .breakfast,
                title: "breakfast / morning table",
                angles: [
                    "morning reset through one concrete object",
                    "small ritual before the day starts",
                    "quiet appetite, light, and table details",
                    "a restrained note about being kind to oneself"
                ],
                avoidPhrases: ["今日份小确幸", "元气满满", "美好的一天开始了", "满满的幸福"],
                examples: [
                    example("早餐不必隆重，能把今天慢慢打开就够了。", .healing, .simplifiedChinese, .breakfast),
                    example("先把这一口吃明白，再和世界讲道理。", .humor, .simplifiedChinese, .breakfast),
                    example("早晨的桌面不用完美，有热气和一点耐心就很好。", .premium, .simplifiedChinese, .breakfast)
                ]
            )
        case .cafe:
            return CaptionStrategyProfile(
                scene: .cafe,
                title: "cafe / coffee pause",
                angles: [
                    "pause between errands or work",
                    "cup, table, window, and background noise",
                    "a small public space that feels private",
                    "coffee as pacing, not performance"
                ],
                avoidPhrases: ["咖啡续命", "下午茶时光", "精致女孩", "仪式感拉满"],
                examples: [
                    example("找个角落坐下，杯子里的时间终于慢了一点。", .healing, .simplifiedChinese, .cafe),
                    example("咖啡负责清醒，我负责假装很有计划。", .humor, .simplifiedChinese, .cafe),
                    example("桌面、光线和一杯咖啡，把今天的节奏压低了半拍。", .premium, .simplifiedChinese, .cafe)
                ]
            )
        case .walking:
            return CaptionStrategyProfile(
                scene: .walking,
                title: "walking / everyday observation",
                angles: [
                    "what was noticed while moving",
                    "street edge, weather, trees, river, small signs",
                    "a walk as a mental reset",
                    "ordinary route with one memorable detail"
                ],
                avoidPhrases: ["随手一拍", "出来走走", "放松一下", "生活很美好"],
                examples: [
                    example("走着走着，脑子里的杂音就被路边的风带走一点。", .healing, .simplifiedChinese, .walking),
                    example("今天的散步路线没有重点，但很会安排细节。", .humor, .simplifiedChinese, .walking),
                    example("路边的光和树影，比计划里的行程更像答案。", .premium, .simplifiedChinese, .walking)
                ]
            )
        case .street:
            return CaptionStrategyProfile(
                scene: .street,
                title: "street / city corner",
                angles: [
                    "city texture without over-explaining",
                    "building, road, sign, light, and crowd rhythm",
                    "a corner that briefly asks to be noticed",
                    "dry humor about the city looking composed"
                ],
                avoidPhrases: ["城市漫步", "街头随拍", "人间烟火", "氛围感拉满"],
                examples: [
                    example("这座城市偶尔很会摆姿势，路过的人只负责发现。", .humor, .simplifiedChinese, .street),
                    example("街角没有剧情，但光线和线条已经把话说完了。", .premium, .simplifiedChinese, .street),
                    example("路过的一小段，也可以有自己的节奏。", .healing, .simplifiedChinese, .street)
                ]
            )
        case .travel:
            return CaptionStrategyProfile(
                scene: .travel,
                title: "travel / away from routine",
                angles: [
                    "place-specific memory without pretending to be profound",
                    "what changed because the user left home",
                    "transport, landmark, hotel, view, weather, local details",
                    "light self-awareness about tourist mode"
                ],
                avoidPhrases: ["说走就走", "诗和远方", "旅行的意义", "逃离城市"],
                examples: [
                    example("来到新的地方，连普通的路牌都像在提醒我：今天不是复制粘贴。", .premium, .simplifiedChinese, .travel),
                    example("游客模式开启，但我尽量装得像路过。", .humor, .simplifiedChinese, .travel),
                    example("把这段路收进相册，也把当时的空气一起带回去。", .healing, .simplifiedChinese, .travel)
                ]
            )
        case .pet:
            return CaptionStrategyProfile(
                scene: .pet,
                title: "pet / companion detail",
                angles: [
                    "specific pose, gaze, paw, fur, chair, bowl, blanket, or room detail",
                    "companionship without syrupy wording",
                    "pet as a tiny character with its own agenda",
                    "relationship between pet and surrounding objects"
                ],
                avoidPhrases: ["好可爱", "萌化了", "治愈了", "小可爱", "陪伴是最长情的告白"],
                examples: [
                    example("它没有解释自己为什么坐在这里，但表情已经很有立场。", .humor, .simplifiedChinese, .pet),
                    example("一只猫把房间占成自己的样子，人类只好安静配合。", .premium, .simplifiedChinese, .pet),
                    example("有些陪伴不需要靠近，出现在画面里就够了。", .healing, .simplifiedChinese, .pet)
                ]
            )
        case .outfit:
            return CaptionStrategyProfile(
                scene: .outfit,
                title: "outfit / self presentation",
                angles: [
                    "one styling decision, silhouette, color, texture, or accessory",
                    "how the outfit changes posture or mood",
                    "mirror/selfie without over-selling",
                    "clean confidence, not exaggerated beauty language"
                ],
                avoidPhrases: ["今日穿搭", "出片", "高级感", "氛围感", "精致女孩"],
                examples: [
                    example("这身不是为了很用力地好看，是为了让今天更像自己。", .premium, .simplifiedChinese, .outfit),
                    example("衣服负责撑住气场，我负责别把它穿成工服。", .humor, .simplifiedChinese, .outfit),
                    example("颜色和线条都刚好，出门前就先把状态调顺了。", .xiaohongshu, .simplifiedChinese, .outfit)
                ]
            )
        case .fitness:
            return CaptionStrategyProfile(
                scene: .fitness,
                title: "fitness / movement record",
                angles: [
                    "small discipline without motivational shouting",
                    "sweat, mat, shoes, equipment, track, gym light",
                    "showing up rather than performance",
                    "body as routine, not punishment"
                ],
                avoidPhrases: ["自律给我自由", "燃烧卡路里", "暴汗", "狠狠拿捏", "变美变瘦"],
                examples: [
                    example("今天没有什么豪言壮语，只有把身体叫醒这件小事。", .healing, .simplifiedChinese, .fitness),
                    example("运动最难的部分不是动作，是说服自己先出现。", .humor, .simplifiedChinese, .fitness),
                    example("一点点出汗，一点点把状态调回自己手里。", .premium, .simplifiedChinese, .fitness)
                ]
            )
        case .sunset:
            return CaptionStrategyProfile(
                scene: .sunset,
                title: "sunset / evening light",
                angles: [
                    "light changing the mood of ordinary objects",
                    "end-of-day pause without sentimental overreach",
                    "sky color, silhouette, window, skyline, water",
                    "quiet closure rather than big life lesson"
                ],
                avoidPhrases: ["落日余晖", "人间值得", "浪漫至死不渝", "温柔了岁月"],
                examples: [
                    example("天色慢下来以后，很多事情也没那么急着要答案。", .healing, .simplifiedChinese, .sunset),
                    example("今天的天空下班比我体面。", .humor, .simplifiedChinese, .sunset),
                    example("光线退场得很慢，像给这一天留了一个干净的句号。", .premium, .simplifiedChinese, .sunset)
                ]
            )
        case .home, .daily:
            return CaptionStrategyProfile(
                scene: .home,
                title: "home / indoor life",
                angles: [
                    "a lived-in corner: chair, sofa, lamp, table, bed, clutter",
                    "comfort through real details, not perfect lifestyle staging",
                    "private space and small routines",
                    "soft humor about domestic disorder"
                ],
                avoidPhrases: ["宅家日常", "生活的温柔", "小确幸", "治愈角落"],
                examples: [
                    example("家里最真实的地方，通常也最不负责好看。", .humor, .simplifiedChinese, .home),
                    example("这个角落没有精心布置，但有生活自己留下的顺序。", .premium, .simplifiedChinese, .home),
                    example("回到熟悉的空间，整个人才慢慢降噪。", .healing, .simplifiedChinese, .home)
                ]
            )
        case .work:
            return CaptionStrategyProfile(
                scene: .work,
                title: "work / desk focus",
                angles: [
                    "desk objects: laptop, notebook, keyboard, coffee, document, screen",
                    "focus without fake ambition",
                    "workday texture and small progress",
                    "wry humor about being productive"
                ],
                avoidPhrases: ["努力搬砖", "打工人", "自律", "冲鸭", "继续加油"],
                examples: [
                    example("桌面看起来很忙，至少说明我和今天认真交过手。", .humor, .simplifiedChinese, .work),
                    example("把事情一件件放回秩序里，也算今天的进度。", .premium, .simplifiedChinese, .work),
                    example("专注不是很响亮的事，但它会慢慢把一天撑起来。", .healing, .simplifiedChinese, .work)
                ]
            )
        case .food:
            return CaptionStrategyProfile(
                scene: .food,
                title: "food / meal detail",
                angles: [
                    "one visible detail: steam, bowl, plate, chopsticks, sauce, table",
                    "meal as a pause, not just happiness",
                    "taste memory without naming unsupported dishes",
                    "restrained appetite and everyday reward"
                ],
                avoidPhrases: ["今日份满足", "好吃到飞起", "干饭", "治愈我的胃", "人间烟火气"],
                examples: [
                    example("这顿饭不用负责惊艳，负责把人稳稳接住就够了。", .healing, .simplifiedChinese, .food),
                    example("先别谈人生，筷子已经替我做了选择。", .humor, .simplifiedChinese, .food),
                    example("盘子里的细节很安静，但足够让这一餐有记忆点。", .premium, .simplifiedChinese, .food)
                ]
            )
        case .unknown:
            return CaptionStrategyProfile(
                scene: .unknown,
                title: "uncertain / evidence-first caption",
                angles: [
                    "write from visible light, framing, objects, or text only",
                    "acknowledge ambiguity through atmosphere, not false detail",
                    "small observation without claiming scene",
                    "safe caption that does not invent facts"
                ],
                avoidPhrases: ["今天真好", "美好时光", "值得记录", "治愈", "小确幸"],
                examples: [
                    example("画面没有把话说满，反而留了一点可以自己理解的空间。", .premium, .simplifiedChinese, .unknown),
                    example("看不出太多剧情，但这一帧的秩序感还挺明确。", .humor, .simplifiedChinese, .unknown),
                    example("先不急着定义它，把当下看到的细节留下来。", .healing, .simplifiedChinese, .unknown)
                ]
            )
        }
    }

    func promptBlock(
        context: CaptionGenerationContext,
        preference: UserPreference,
        sampleStore: CaptionSampleLibraryStore = CaptionSampleLibraryStore(),
        compact: Bool = false
    ) -> String {
        let profile = profile(for: context)
        let language = preference.preferredCaptionLanguage
        let localSamples = sampleStore.topSamples(
            for: context,
            language: language,
            platform: preference.preferredPlatforms.first ?? .general,
            limit: compact ? 2 : 4
        )
        let builtInExamples = profile.examples(for: language).prefix(compact ? 2 : 4).map { "- \($0.text)" }
        let localExampleLines = localSamples.map { "- \($0.text)" }

        if compact {
            return """
            Caption strategy library:
            - Scene strategy: \(profile.title).
            - Angles: \(profile.angles.prefix(2).joined(separator: " / ")).
            - Avoid weak scene phrases: \(profile.avoidPhrases.prefix(4).joined(separator: ", ")).
            - Reference examples, do not copy:
            \(builtInExamples.isEmpty ? "- Use one concrete photo detail plus a restrained point of view." : builtInExamples.joined(separator: "\n"))
            \(localExampleLines.isEmpty ? "" : "User-local examples:\n\(localExampleLines.joined(separator: "\n"))")
            """
        }

        return """
        Caption strategy library:
        - Product scene strategy: \(profile.title).
        - Use one clear writing angle, not all angles at once.
        - Available angles: \(profile.angles.joined(separator: " / ")).
        - Avoid these weak or overused phrases for this scene: \(profile.avoidPhrases.joined(separator: ", ")).
        - Start from a concrete visual detail, then add a small point of view.
        - The caption may be quiet, witty, or polished, but it must not sound childish, fake inspirational, or like a generic template.

        Built-in mature examples:
        \(builtInExamples.isEmpty ? "- Use a precise observation plus a restrained point of view." : builtInExamples.joined(separator: "\n"))

        User-local high-quality examples:
        \(localExampleLines.isEmpty ? "- No accepted user examples yet. Do not invent user taste beyond generation preferences." : localExampleLines.joined(separator: "\n"))
        """
    }

    func fallbackCandidates(
        context: CaptionGenerationContext,
        language: CaptionLanguage,
        platform: SocialPlatform,
        lengthLevel: LengthLevel
    ) -> [CaptionCandidate] {
        let profile = profile(for: context)
        let examples = profile.examples(for: language)
        guard !examples.isEmpty else {
            return []
        }

        return examples.prefix(5).map { example in
            CaptionCandidate(
                text: example.text,
                style: example.style,
                platform: platform == .general && example.style == .xiaohongshu ? .xiaohongshu : platform,
                lengthLevel: lengthLevel,
                emojiLevel: .none,
                scene: example.scene
            )
        }
    }

    func qualityScore(
        text: String,
        context: CaptionGenerationContext,
        preference: UserPreference,
        editSummary: CaptionEditSummary?
    ) -> CaptionStrategyQualityAssessment {
        let profile = profile(for: context)
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercasedText = trimmedText.lowercased()
        var score = 0.52
        var reasons: [String] = []

        if trimmedText.count >= 12 {
            score += 0.08
            reasons.append("enough substance")
        }

        if trimmedText.count > 120 {
            score -= 0.10
            reasons.append("too long for a reusable local sample")
        }

        if profile.avoidPhrases.contains(where: { trimmedText.localizedCaseInsensitiveContains($0) }) {
            score -= 0.18
            reasons.append("contains scene-specific weak phrase")
        }

        if let editSummary, editSummary.wasEdited {
            score += 0.16
            reasons.append("user edited before sharing")
        }

        if preference.textPreference.likedPhrases.contains(where: { trimmedText.contains($0) }) {
            score += 0.08
            reasons.append("matches learned liked phrase")
        }

        if preference.dislikedPhrasesForPrompt.contains(where: { trimmedText.contains($0) }) {
            score -= 0.16
            reasons.append("contains learned avoided phrase")
        }

        let exampleSimilarity = profile.examples(for: preference.preferredCaptionLanguage)
            .map { similarity(trimmedText, $0.text) }
            .max() ?? 0
        if exampleSimilarity > 0.72 {
            score -= 0.10
            reasons.append("too close to built-in example")
        } else if exampleSimilarity >= 0.28 {
            score += 0.08
            reasons.append("fits strategy without copying it")
        }

        if containsMetadataLeak(lowercasedText) {
            score -= 0.30
            reasons.append("contains metadata-like text")
        }

        if reasons.isEmpty {
            reasons.append("neutral strategy fit")
        }

        return CaptionStrategyQualityAssessment(score: min(1.0, max(0.0, score)), reasons: reasons)
    }

    func resolvedScene(for context: CaptionGenerationContext) -> SceneType {
        if let productScene = context.analysisResult?.sceneResolution.scene, productScene != .unknown {
            return SceneType(productScene: productScene)
        }

        if context.sceneTags.contains("breakfast") {
            return .breakfast
        }

        if context.sceneTags.contains("cafe") || context.sceneTags.contains("coffee") {
            return .cafe
        }

        if context.sceneTags.contains("walking") || context.sceneTags.contains("walk") {
            return .walking
        }

        if context.sceneTags.contains("outfit") {
            return .outfit
        }

        if context.sceneTags.contains("fitness") || context.sceneTags.contains("workout") {
            return .fitness
        }

        if context.sceneTags.contains("sunset") {
            return .sunset
        }

        if context.sceneTags.contains("home") {
            return .home
        }

        return context.primaryScene
    }

    private func example(_ text: String, _ style: CaptionStyle, _ language: CaptionLanguage, _ scene: SceneType) -> CaptionStrategyExample {
        CaptionStrategyExample(text: text, style: style, language: language, scene: scene)
    }

    private func containsMetadataLeak(_ text: String) -> Bool {
        ["premium", "instagram", "medium", "scene", "style", "lengthlevel", "emojilevel"].contains { text.contains($0) }
    }

    private func similarity(_ lhs: String, _ rhs: String) -> Double {
        let lhsTokens = Set(tokens(from: lhs))
        let rhsTokens = Set(tokens(from: rhs))
        guard !lhsTokens.isEmpty, !rhsTokens.isEmpty else {
            return 0
        }

        let overlap = lhsTokens.intersection(rhsTokens).count
        let union = lhsTokens.union(rhsTokens).count
        return Double(overlap) / Double(union)
    }

    private func tokens(from text: String) -> [String] {
        let separators = CharacterSet(charactersIn: "，。！？、；：,.!?;:\n")
            .union(.whitespacesAndNewlines)
        let fragments = text
            .lowercased()
            .components(separatedBy: separators)
            .flatMap { fragment -> [String] in
                if fragment.unicodeScalars.contains(where: { (0x4E00...0x9FFF).contains(Int($0.value)) }) {
                    return fragment.map(String.init)
                }

                return [fragment]
            }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return fragments
    }
}

struct CaptionStrategyProfile: Equatable {
    let scene: SceneType
    let title: String
    let angles: [String]
    let avoidPhrases: [String]
    let examples: [CaptionStrategyExample]

    func examples(for language: CaptionLanguage) -> [CaptionStrategyExample] {
        examples.filter { $0.language == language }
    }
}

struct CaptionStrategyExample: Equatable {
    let text: String
    let style: CaptionStyle
    let language: CaptionLanguage
    let scene: SceneType
}

struct CaptionStrategyQualityAssessment: Equatable {
    let score: Double
    let reasons: [String]
}
