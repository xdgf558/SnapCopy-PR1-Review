import Combine
import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case simplifiedChinese = "zh-Hans"
    case english = "en"
    case japanese = "ja"
    case traditionalChinese = "zh-Hant"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .simplifiedChinese:
            "简体中文"
        case .english:
            "English"
        case .japanese:
            "日本語"
        case .traditionalChinese:
            "繁體中文"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .simplifiedChinese:
            "zh-Hans"
        case .english:
            "en"
        case .japanese:
            "ja"
        case .traditionalChinese:
            "zh-Hant"
        }
    }
}

final class AppLanguageManager: ObservableObject {
    private let storageKey = "snapcopy.appLanguage"
    private let userDefaults: UserDefaults

    @Published var language: AppLanguage {
        didSet {
            userDefaults.set(language.rawValue, forKey: storageKey)
        }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        if let rawValue = userDefaults.string(forKey: storageKey),
           let language = AppLanguage(rawValue: rawValue) {
            self.language = language
        } else {
            self.language = .simplifiedChinese
        }
    }

    func update(_ language: AppLanguage) {
        self.language = language
    }
}

enum AppTextKey {
    case settings
    case settingsAndPreferences
    case appSubtitle
    case selectedPhotoPreview
    case noPhotoSelected
    case photoStyle
    case photoIntro
    case loadingPhoto
    case album
    case camera
    case generateCaption
    case regenerate
    case sceneTitle
    case platformTitle
    case platformTemplateNote
    case lengthTitle
    case lengthTemplateNote
    case plusCreativeImageTitle
    case plusCreativeImageSubtitle
    case generateCreativeImage
    case generatingCreativeImage
    case shareCreativeImage
    case creativeImagePreview
    case creativeImageGenerated
    case creativeImageLocalFallbackUsed
    case creativeImageGenerationFailed
    case creativeImagePlusRequired
    case appleImagePlaygroundUnavailable
    case creativeImageProReserved
    case proCloudFrameworkTitle
    case proCloudFrameworkReady
    case recognizingScene
    case generatingCaption
    case generatedCaptionsTitle
    case copy
    case share
    case editBeforeShareTitle
    case editBeforeShareSubtitle
    case originalCaption
    case finalCaption
    case restoreOriginal
    case shareAsCard
    case shareAsCardSubtitle
    case confirmShare
    case cancel
    case finalCaptionEmpty
    case favorite
    case favorited
    case dislikeNext
    case copied
    case shareCaptionCopied
    case savedToFavorites
    case removedFromFavorites
    case disliked
    case historyAndFavorites
    case allHistory
    case favorites
    case historyEmpty
    case favoritesEmpty
    case delete
    case preferenceTitle
    case preferenceSubtitle
    case interfaceLanguage
    case interfaceLanguagePicker
    case interfaceLanguageNote
    case captionLanguage
    case generationLanguage
    case captionLanguageNote
    case membershipMock
    case currentLevel
    case advancedStyle
    case cloudEnhance
    case watermarkRemoval
    case available
    case unavailable
    case todayUsage
    case captionGeneration
    case basicEnhancement
    case unlimited
    case resetUsage
    case betaUsageNote
    case localAI
    case currentStatus
    case preferenceLearning
    case runningOnDevice
    case localSave
    case connected
    case realPayment
    case laterStage
    case aboutSnapCopy
    case version
    case updateNotes
    case developer
    case betaTestGuide
    case betaTestGuideText
    case feedback
    case feedbackIntro
    case copyFeedbackEmail
    case feedbackEmailCopied
    case paywallTitle
    case paywallSubtitle
    case paywallTodayCount
    case paywallGotIt
    case paywallNavigationTitle
}

extension AppLanguage {
    func text(_ key: AppTextKey) -> String {
        Self.table[key]?[self] ?? Self.table[key]?[.simplifiedChinese] ?? ""
    }

    func platformName(_ platform: SocialPlatform) -> String {
        switch (self, platform) {
        case (.simplifiedChinese, .general):
            return "通用"
        case (.simplifiedChinese, .wechat):
            return "朋友圈"
        case (.simplifiedChinese, .xiaohongshu):
            return "小红书"
        case (.simplifiedChinese, .instagram):
            return "Instagram"
        case (.simplifiedChinese, .x):
            return "X"
        case (.english, .general):
            return "General"
        case (.english, .wechat):
            return "WeChat"
        case (.english, .xiaohongshu):
            return "Xiaohongshu"
        case (.english, .instagram):
            return "Instagram"
        case (.english, .x):
            return "X"
        case (.japanese, .general):
            return "汎用"
        case (.japanese, .wechat):
            return "WeChat"
        case (.japanese, .xiaohongshu):
            return "小紅書"
        case (.japanese, .instagram):
            return "Instagram"
        case (.japanese, .x):
            return "X"
        case (.traditionalChinese, .general):
            return "通用"
        case (.traditionalChinese, .wechat):
            return "朋友圈"
        case (.traditionalChinese, .xiaohongshu):
            return "小紅書"
        case (.traditionalChinese, .instagram):
            return "Instagram"
        case (.traditionalChinese, .x):
            return "X"
        }
    }

    func lengthLevelName(_ lengthLevel: LengthLevel) -> String {
        switch (self, lengthLevel) {
        case (.simplifiedChinese, .short):
            return "简短"
        case (.simplifiedChinese, .medium):
            return "自然"
        case (.simplifiedChinese, .long):
            return "详细"
        case (.english, .short):
            return "Short"
        case (.english, .medium):
            return "Natural"
        case (.english, .long):
            return "Detailed"
        case (.japanese, .short):
            return "短め"
        case (.japanese, .medium):
            return "自然"
        case (.japanese, .long):
            return "詳しく"
        case (.traditionalChinese, .short):
            return "簡短"
        case (.traditionalChinese, .medium):
            return "自然"
        case (.traditionalChinese, .long):
            return "詳細"
        }
    }

    func generationModeName(_ mode: CaptionGenerationMode) -> String {
        switch (self, mode) {
        case (.simplifiedChinese, .mock):
            return "基础文案"
        case (.english, .mock):
            return "Basic captions"
        case (.japanese, .mock):
            return "基本文案"
        case (.traditionalChinese, .mock):
            return "基礎文案"
        case (.simplifiedChinese, .localAI):
            return "本机 AI"
        case (.english, .localAI):
            return "On-device AI"
        case (.japanese, .localAI):
            return "オンデバイス AI"
        case (.traditionalChinese, .localAI):
            return "本機 AI"
        case (.simplifiedChinese, .cloudEnhanced):
            return "云端增强"
        case (.english, .cloudEnhanced):
            return "Cloud enhancement"
        case (.japanese, .cloudEnhanced):
            return "クラウド強化"
        case (.traditionalChinese, .cloudEnhanced):
            return "雲端增強"
        }
    }

    func generationModeLine(_ mode: CaptionGenerationMode) -> String {
        switch self {
        case .simplifiedChinese:
            "本次生成：\(generationModeName(mode))"
        case .english:
            "Generated with \(generationModeName(mode))"
        case .japanese:
            "今回の生成：\(generationModeName(mode))"
        case .traditionalChinese:
            "本次生成：\(generationModeName(mode))"
        }
    }

    func creativeImageStyleName(_ style: CreativeImageStyle) -> String {
        switch (self, style) {
        case (.simplifiedChinese, .cuteHandDrawn):
            return "可爱手绘"
        case (.simplifiedChinese, .cover):
            return "封面图"
        case (.simplifiedChinese, .xiaohongshuSticker):
            return "贴纸图"
        case (.english, .cuteHandDrawn):
            return "Cute sketch"
        case (.english, .cover):
            return "Cover"
        case (.english, .xiaohongshuSticker):
            return "Sticker"
        case (.japanese, .cuteHandDrawn):
            return "かわいい手描き"
        case (.japanese, .cover):
            return "カバー"
        case (.japanese, .xiaohongshuSticker):
            return "ステッカー"
        case (.traditionalChinese, .cuteHandDrawn):
            return "可愛手繪"
        case (.traditionalChinese, .cover):
            return "封面圖"
        case (.traditionalChinese, .xiaohongshuSticker):
            return "貼紙圖"
        }
    }

    func creativeImageStyleDescription(_ style: CreativeImageStyle) -> String {
        switch (self, style) {
        case (.simplifiedChinese, .cuteHandDrawn):
            return "把照片变成柔和可爱的手绘分享图。"
        case (.simplifiedChinese, .cover):
            return "生成更适合标题排版的社交封面图。"
        case (.simplifiedChinese, .xiaohongshuSticker):
            return "生成偏小红书风格的可爱装饰贴纸图。"
        case (.english, .cuteHandDrawn):
            return "Turn the photo into a soft, cute hand-drawn share image."
        case (.english, .cover):
            return "Create a clean social cover image with room for titles."
        case (.english, .xiaohongshuSticker):
            return "Create a playful Xiaohongshu-style decorative sticker image."
        case (.japanese, .cuteHandDrawn):
            return "写真を柔らかくかわいい手描き風の共有画像にします。"
        case (.japanese, .cover):
            return "タイトルを載せやすいSNSカバー画像を生成します。"
        case (.japanese, .xiaohongshuSticker):
            return "小紅書風のかわいい装飾ステッカー画像を生成します。"
        case (.traditionalChinese, .cuteHandDrawn):
            return "把照片變成柔和可愛的手繪分享圖。"
        case (.traditionalChinese, .cover):
            return "生成更適合標題排版的社交封面圖。"
        case (.traditionalChinese, .xiaohongshuSticker):
            return "生成偏小紅書風格的可愛裝飾貼紙圖。"
        }
    }

    func captionUsageText(level: EntitlementLevel, used: Int) -> String {
        if let limit = level.dailyCaptionGenerationLimit {
            switch self {
            case .simplifiedChinese:
                return "\(level.displayName) 今日生成 \(used)/\(limit)"
            case .english:
                return "\(level.displayName): \(used)/\(limit) today"
            case .japanese:
                return "\(level.displayName) 本日 \(used)/\(limit)"
            case .traditionalChinese:
                return "\(level.displayName) 今日生成 \(used)/\(limit)"
            }
        }

        switch self {
        case .simplifiedChinese:
            return "\(level.displayName)：今日生成不限次数"
        case .english:
            return "\(level.displayName): unlimited today"
        case .japanese:
            return "\(level.displayName)：本日無制限"
        case .traditionalChinese:
            return "\(level.displayName)：今日生成不限次數"
        }
    }

    func usageValue(used: Int, limit: Int?) -> String {
        if let limit {
            return "\(used) / \(limit)"
        }

        return "\(used) / \(text(.unlimited))"
    }

    func styleName(_ style: CaptionStyle) -> String {
        switch (self, style) {
        case (.simplifiedChinese, .healing):
            return "治愈"
        case (.simplifiedChinese, .humor):
            return "幽默"
        case (.simplifiedChinese, .premium):
            return "高级感"
        case (.simplifiedChinese, .xiaohongshu):
            return "小红书"
        case (.simplifiedChinese, .concise):
            return "简短"
        case (.simplifiedChinese, .poetic):
            return "文艺"
        case (.simplifiedChinese, .daily):
            return "日常"
        case (.english, .healing):
            return "Soft"
        case (.english, .humor):
            return "Playful"
        case (.english, .premium):
            return "Premium"
        case (.english, .xiaohongshu):
            return "Lifestyle"
        case (.english, .concise):
            return "Short"
        case (.english, .poetic):
            return "Poetic"
        case (.english, .daily):
            return "Daily"
        case (.japanese, .healing):
            return "癒やし"
        case (.japanese, .humor):
            return "ユーモア"
        case (.japanese, .premium):
            return "上質"
        case (.japanese, .xiaohongshu):
            return "ライフスタイル"
        case (.japanese, .concise):
            return "短め"
        case (.japanese, .poetic):
            return "詩的"
        case (.japanese, .daily):
            return "日常"
        case (.traditionalChinese, .healing):
            return "療癒"
        case (.traditionalChinese, .humor):
            return "幽默"
        case (.traditionalChinese, .premium):
            return "高級感"
        case (.traditionalChinese, .xiaohongshu):
            return "小紅書"
        case (.traditionalChinese, .concise):
            return "簡短"
        case (.traditionalChinese, .poetic):
            return "文藝"
        case (.traditionalChinese, .daily):
            return "日常"
        }
    }

    func presetName(_ preset: ImageEnhancementPreset) -> String {
        switch (self, preset) {
        case (.simplifiedChinese, .natural):
            return "自然"
        case (.simplifiedChinese, .warm):
            return "暖调"
        case (.simplifiedChinese, .clean):
            return "清透"
        case (.english, .natural):
            return "Natural"
        case (.english, .warm):
            return "Warm"
        case (.english, .clean):
            return "Clean"
        case (.japanese, .natural):
            return "自然"
        case (.japanese, .warm):
            return "暖かめ"
        case (.japanese, .clean):
            return "クリア"
        case (.traditionalChinese, .natural):
            return "自然"
        case (.traditionalChinese, .warm):
            return "暖調"
        case (.traditionalChinese, .clean):
            return "清透"
        }
    }

    func manualSceneName(_ option: ManualSceneOption) -> String {
        switch (self, option) {
        case (.simplifiedChinese, .auto):
            return "自动识别"
        case (.simplifiedChinese, .breakfast):
            return "早餐"
        case (.simplifiedChinese, .coffee):
            return "咖啡"
        case (.simplifiedChinese, .walk):
            return "散步"
        case (.simplifiedChinese, .travel):
            return "旅行"
        case (.simplifiedChinese, .outfit):
            return "穿搭"
        case (.simplifiedChinese, .pet):
            return "宠物"
        case (.simplifiedChinese, .workout):
            return "运动"
        case (.simplifiedChinese, .street):
            return "街景"
        case (.simplifiedChinese, .food):
            return "美食"
        case (.simplifiedChinese, .work):
            return "工作"
        case (.simplifiedChinese, .other):
            return "日常"
        case (.english, .auto):
            return "Auto"
        case (.english, .breakfast):
            return "Breakfast"
        case (.english, .coffee):
            return "Coffee"
        case (.english, .walk):
            return "Walk"
        case (.english, .travel):
            return "Travel"
        case (.english, .outfit):
            return "Outfit"
        case (.english, .pet):
            return "Pet"
        case (.english, .workout):
            return "Workout"
        case (.english, .street):
            return "Street"
        case (.english, .food):
            return "Food"
        case (.english, .work):
            return "Work"
        case (.english, .other):
            return "Daily"
        case (.japanese, .auto):
            return "自動認識"
        case (.japanese, .breakfast):
            return "朝食"
        case (.japanese, .coffee):
            return "コーヒー"
        case (.japanese, .walk):
            return "散歩"
        case (.japanese, .travel):
            return "旅行"
        case (.japanese, .outfit):
            return "コーデ"
        case (.japanese, .pet):
            return "ペット"
        case (.japanese, .workout):
            return "運動"
        case (.japanese, .street):
            return "街角"
        case (.japanese, .food):
            return "グルメ"
        case (.japanese, .work):
            return "仕事"
        case (.japanese, .other):
            return "日常"
        case (.traditionalChinese, .auto):
            return "自動識別"
        case (.traditionalChinese, .breakfast):
            return "早餐"
        case (.traditionalChinese, .coffee):
            return "咖啡"
        case (.traditionalChinese, .walk):
            return "散步"
        case (.traditionalChinese, .travel):
            return "旅行"
        case (.traditionalChinese, .outfit):
            return "穿搭"
        case (.traditionalChinese, .pet):
            return "寵物"
        case (.traditionalChinese, .workout):
            return "運動"
        case (.traditionalChinese, .street):
            return "街景"
        case (.traditionalChinese, .food):
            return "美食"
        case (.traditionalChinese, .work):
            return "工作"
        case (.traditionalChinese, .other):
            return "日常"
        }
    }

    func entitlementDescription(_ level: EntitlementLevel) -> String {
        switch (self, level) {
        case (.simplifiedChinese, .free):
            return "基础体验"
        case (.simplifiedChinese, .plus):
            return "创作者预览"
        case (.simplifiedChinese, .pro):
            return "专业能力预览"
        case (.english, .free):
            return "Basic"
        case (.english, .plus):
            return "Creator preview"
        case (.english, .pro):
            return "Pro preview"
        case (.japanese, .free):
            return "基本体験"
        case (.japanese, .plus):
            return "クリエイター プレビュー"
        case (.japanese, .pro):
            return "プロ向けプレビュー"
        case (.traditionalChinese, .free):
            return "基礎體驗"
        case (.traditionalChinese, .plus):
            return "創作者預覽"
        case (.traditionalChinese, .pro):
            return "專業能力預覽"
        }
    }

    func localAIStatusText(_ status: LocalAIAvailabilityStatus) -> (title: String, detail: String) {
        switch status {
        case .available:
            switch self {
            case .simplifiedChinese:
                return ("本机 AI 可用", "将优先使用 Apple Foundation Models。")
            case .english:
                return ("On-device AI available", "Apple Foundation Models will be used first.")
            case .japanese:
                return ("オンデバイス AI 利用可", "Apple Foundation Models を優先して使用します。")
            case .traditionalChinese:
                return ("本機 AI 可用", "將優先使用 Apple Foundation Models。")
            }
        case .unavailable(let reason):
            switch self {
            case .simplifiedChinese:
                return ("本机 AI 不可用", reason)
            case .english:
                return ("On-device AI unavailable", "On-device AI is not available on this device or system yet.")
            case .japanese:
                return ("オンデバイス AI 利用不可", "このデバイスまたはシステムでは、まだオンデバイス AI を利用できません。")
            case .traditionalChinese:
                return ("本機 AI 不可用", "這台裝置或系統目前尚無法使用本機 AI。")
            }
        }
    }

    func developmentNotesText() -> String {
        switch self {
        case .simplifiedChinese:
            return """
            1. 云端增强已接入真实 DeepSeek 文案 provider，并继续只上传场景 JSON、偏好、平台和语言。
            2. 云端额度改为以后端 D1 为准，生成成功后同步剩余次数，provider 失败不扣次数。
            3. 后端新增基础成本保护：服务端计划兜底、分钟频率限制、异常请求记录和每日真实 provider 上限。
            """
        case .english:
            return """
            1. Cloud enhancement now uses the real DeepSeek caption provider while still sending only scene JSON, preferences, platform, and language.
            2. Cloud quota now follows backend D1 state. Successful generations sync remaining quota, and provider failures do not consume quota.
            3. Added basic backend cost guards: server-side plan fallback, per-minute rate limits, abnormal request logs, and a daily real-provider cap.
            """
        case .japanese:
            return """
            1. クラウド強化は実際の DeepSeek 文案 provider に接続しました。送信内容は引き続き scene JSON、好み、プラットフォーム、言語のみです。
            2. クラウド残り回数はバックエンド D1 を基準に同期します。provider 失敗時は回数を消費しません。
            3. 基本的なコスト保護を追加しました。サーバー側 plan、分単位の制限、異常リクエスト記録、実 provider の日次上限を含みます。
            """
        case .traditionalChinese:
            return """
            1. 雲端增強已接入真實 DeepSeek 文案 provider，並繼續只上傳場景 JSON、偏好、平台和語言。
            2. 雲端額度改為以後端 D1 為準，生成成功後同步剩餘次數，provider 失敗不扣次數。
            3. 後端新增基礎成本保護：服務端計畫兜底、分鐘頻率限制、異常請求記錄和每日真實 provider 上限。
            """
        }
    }
}

private extension AppLanguage {
    static let table: [AppTextKey: [AppLanguage: String]] = [
        .settings: [.simplifiedChinese: "设置", .english: "Settings", .japanese: "設定", .traditionalChinese: "設定"],
        .settingsAndPreferences: [.simplifiedChinese: "设置与偏好", .english: "Settings & preferences", .japanese: "設定と好み", .traditionalChinese: "設定與偏好"],
        .appSubtitle: [.simplifiedChinese: "拍一下，发得更好看", .english: "Snap, caption, share beautifully", .japanese: "撮って、もっと素敵にシェア", .traditionalChinese: "拍一下，發得更好看"],
        .selectedPhotoPreview: [.simplifiedChinese: "已选择的照片预览", .english: "Selected photo preview", .japanese: "選択した写真のプレビュー", .traditionalChinese: "已選擇的照片預覽"],
        .noPhotoSelected: [.simplifiedChinese: "未选择照片", .english: "No photo selected", .japanese: "写真未選択", .traditionalChinese: "未選擇照片"],
        .photoStyle: [.simplifiedChinese: "图片风格", .english: "Photo style", .japanese: "写真スタイル", .traditionalChinese: "圖片風格"],
        .photoIntro: [.simplifiedChinese: "选一张照片，让我帮你写一段适合分享的文案。", .english: "Choose a photo and I’ll write a share-ready caption.", .japanese: "写真を選ぶと、シェア向けの文案を作ります。", .traditionalChinese: "選一張照片，讓我幫你寫一段適合分享的文案。"],
        .loadingPhoto: [.simplifiedChinese: "正在加载照片...", .english: "Loading photo...", .japanese: "写真を読み込み中...", .traditionalChinese: "正在載入照片..."],
        .album: [.simplifiedChinese: "相册", .english: "Library", .japanese: "アルバム", .traditionalChinese: "相簿"],
        .camera: [.simplifiedChinese: "拍照", .english: "Camera", .japanese: "撮影", .traditionalChinese: "拍照"],
        .generateCaption: [.simplifiedChinese: "生成文案", .english: "Generate caption", .japanese: "文案を生成", .traditionalChinese: "生成文案"],
        .regenerate: [.simplifiedChinese: "重新生成", .english: "Regenerate", .japanese: "再生成", .traditionalChinese: "重新生成"],
        .sceneTitle: [.simplifiedChinese: "照片场景", .english: "Photo scene", .japanese: "写真シーン", .traditionalChinese: "照片場景"],
        .platformTitle: [.simplifiedChinese: "发布平台", .english: "Sharing platform", .japanese: "共有先", .traditionalChinese: "發布平台"],
        .platformTemplateNote: [.simplifiedChinese: "会按所选平台调整语气和长度，当前为基础模板。", .english: "Tone and length follow the selected platform. These are basic templates for now.", .japanese: "選んだ共有先に合わせて語気と長さを調整します。現在は基本テンプレートです。", .traditionalChinese: "會按所選平台調整語氣和長度，目前為基礎模板。"],
        .lengthTitle: [.simplifiedChinese: "文案长度", .english: "Caption length", .japanese: "文案の長さ", .traditionalChinese: "文案長度"],
        .lengthTemplateNote: [.simplifiedChinese: "简短适合快速发布，自然适合大多数场景，详细适合朋友圈和小红书。", .english: "Short is for quick posts, Natural fits most photos, and Detailed suits WeChat and Xiaohongshu-style sharing.", .japanese: "短めは素早い投稿向け、自然は多くの写真向け、詳しくは WeChat や小紅書風の共有に向いています。", .traditionalChinese: "簡短適合快速發布，自然適合大多數場景，詳細適合朋友圈和小紅書。"],
        .plusCreativeImageTitle: [.simplifiedChinese: "Pro 创作图", .english: "Pro creative image", .japanese: "Pro 画像作成", .traditionalChinese: "Pro 創作圖"],
        .plusCreativeImageSubtitle: [.simplifiedChinese: "当前测试版暂不开放。后续接入云端大模型后，再用于可爱手绘、封面图和贴纸图。", .english: "Unavailable in this beta. It will return with cloud model support for hand-drawn images, covers, and stickers.", .japanese: "現在のベータ版では利用できません。今後クラウドモデル接続後に、手描き風、カバー、ステッカー画像として再開します。", .traditionalChinese: "目前測試版暫不開放。後續接入雲端大模型後，再用於可愛手繪、封面圖和貼紙圖。"],
        .generateCreativeImage: [.simplifiedChinese: "生成创作图", .english: "Generate image", .japanese: "画像を生成", .traditionalChinese: "生成創作圖"],
        .generatingCreativeImage: [.simplifiedChinese: "正在生成创作图...", .english: "Generating image...", .japanese: "画像を生成中...", .traditionalChinese: "正在生成創作圖..."],
        .shareCreativeImage: [.simplifiedChinese: "分享创作图", .english: "Share image", .japanese: "画像を共有", .traditionalChinese: "分享創作圖"],
        .creativeImagePreview: [.simplifiedChinese: "创作图预览", .english: "Creative image preview", .japanese: "生成画像プレビュー", .traditionalChinese: "創作圖預覽"],
        .creativeImageGenerated: [.simplifiedChinese: "创作图已生成。", .english: "Creative image generated.", .japanese: "画像を生成しました。", .traditionalChinese: "創作圖已生成。"],
        .creativeImageLocalFallbackUsed: [.simplifiedChinese: "Apple 图像生成遇到语言限制，已使用本机模板生成。", .english: "Apple image generation hit a language limit, so a local template was used.", .japanese: "Apple の画像生成が言語制限に当たったため、ローカルテンプレートで生成しました。", .traditionalChinese: "Apple 圖像生成遇到語言限制，已使用本機模板生成。"],
        .creativeImageGenerationFailed: [.simplifiedChinese: "创作图生成失败，请稍后重试。", .english: "Creative image generation failed. Please try again later.", .japanese: "画像生成に失敗しました。後でもう一度お試しください。", .traditionalChinese: "創作圖生成失敗，請稍後重試。"],
        .creativeImagePlusRequired: [.simplifiedChinese: "这是 Plus 功能。测试时可在设置里把会员 Mock 切到 Plus。", .english: "This is a Plus feature. For testing, switch Membership mock to Plus in Settings.", .japanese: "これは Plus 機能です。テスト時は設定の会員 Mock を Plus に切り替えてください。", .traditionalChinese: "這是 Plus 功能。測試時可在設定裡把會員 Mock 切到 Plus。"],
        .appleImagePlaygroundUnavailable: [.simplifiedChinese: "当前设备暂不可用，需要支持 Apple Intelligence / Image Playground。", .english: "Unavailable on this device. Apple Intelligence / Image Playground support is required.", .japanese: "この端末では現在利用できません。Apple Intelligence / Image Playground 対応が必要です。", .traditionalChinese: "目前裝置暫不可用，需要支援 Apple Intelligence / Image Playground。"],
        .creativeImageProReserved: [.simplifiedChinese: "已调整为后续 Pro 云端增强功能，当前版本先不开放测试。", .english: "Reserved for a later Pro cloud enhancement release. Testing is disabled in this version.", .japanese: "今後の Pro クラウド強化機能として予約済みです。このバージョンではテストを停止しています。", .traditionalChinese: "已調整為後續 Pro 雲端增強功能，目前版本先不開放測試。"],
        .proCloudFrameworkTitle: [.simplifiedChinese: "Pro 云端增强框架", .english: "Pro cloud framework", .japanese: "Pro クラウド枠組み", .traditionalChinese: "Pro 雲端增強框架"],
        .proCloudFrameworkReady: [.simplifiedChinese: "已预留接口，暂未接入外部大模型 API。", .english: "Interface reserved. No external model API is connected yet.", .japanese: "インターフェイスのみ用意済み。外部モデル API は未接続です。", .traditionalChinese: "已預留接口，暫未接入外部大模型 API。"],
        .recognizingScene: [.simplifiedChinese: "正在识别照片场景...", .english: "Recognizing photo scene...", .japanese: "写真シーンを認識中...", .traditionalChinese: "正在識別照片場景..."],
        .generatingCaption: [.simplifiedChinese: "正在生成文案...", .english: "Generating caption...", .japanese: "文案を生成中...", .traditionalChinese: "正在生成文案..."],
        .generatedCaptionsTitle: [.simplifiedChinese: "为你生成的文案", .english: "Caption for you", .japanese: "おすすめ文案", .traditionalChinese: "為你生成的文案"],
        .copy: [.simplifiedChinese: "复制", .english: "Copy", .japanese: "コピー", .traditionalChinese: "複製"],
        .share: [.simplifiedChinese: "分享", .english: "Share", .japanese: "共有", .traditionalChinese: "分享"],
        .editBeforeShareTitle: [.simplifiedChinese: "发布前编辑", .english: "Edit before sharing", .japanese: "共有前に編集", .traditionalChinese: "發布前編輯"],
        .editBeforeShareSubtitle: [.simplifiedChinese: "你可以先改成自己真正想发的样子。确认分享后，这次最终文案会只在本机用于优化你的偏好。", .english: "Adjust the caption into what you would actually post. After sharing, the final text is used locally to improve your preferences.", .japanese: "実際に投稿したい文案に整えてください。共有後、この最終文案は端末内だけで好みの最適化に使われます。", .traditionalChinese: "你可以先改成自己真正想發的樣子。確認分享後，這次最終文案只會在本機用於優化你的偏好。"],
        .originalCaption: [.simplifiedChinese: "原始文案", .english: "Original caption", .japanese: "元の文案", .traditionalChinese: "原始文案"],
        .finalCaption: [.simplifiedChinese: "最终发布文案", .english: "Final caption", .japanese: "最終文案", .traditionalChinese: "最終發布文案"],
        .restoreOriginal: [.simplifiedChinese: "还原", .english: "Restore", .japanese: "元に戻す", .traditionalChinese: "還原"],
        .shareAsCard: [.simplifiedChinese: "生成图文卡片", .english: "Create caption card", .japanese: "文案カードを作成", .traditionalChinese: "生成圖文卡片"],
        .shareAsCardSubtitle: [.simplifiedChinese: "把照片和文案合成一张图，适合朋友圈等不会自动带文字的 App。", .english: "Merge the photo and caption into one image for apps that do not auto-fill shared text.", .japanese: "写真と文案を1枚の画像にまとめ、共有文が自動入力されない App 向けに使えます。", .traditionalChinese: "把照片和文案合成一張圖，適合朋友圈等不會自動帶文字的 App。"],
        .confirmShare: [.simplifiedChinese: "确认分享", .english: "Share", .japanese: "共有する", .traditionalChinese: "確認分享"],
        .cancel: [.simplifiedChinese: "取消", .english: "Cancel", .japanese: "キャンセル", .traditionalChinese: "取消"],
        .finalCaptionEmpty: [.simplifiedChinese: "最终文案不能为空。", .english: "Final caption can’t be empty.", .japanese: "最終文案は空にできません。", .traditionalChinese: "最終文案不能為空。"],
        .favorite: [.simplifiedChinese: "收藏", .english: "Favorite", .japanese: "お気に入り", .traditionalChinese: "收藏"],
        .favorited: [.simplifiedChinese: "已收藏", .english: "Favorited", .japanese: "保存済み", .traditionalChinese: "已收藏"],
        .dislikeNext: [.simplifiedChinese: "不喜欢，换一条", .english: "Not this, try another", .japanese: "苦手、別案へ", .traditionalChinese: "不喜歡，換一條"],
        .copied: [.simplifiedChinese: "文案已复制。", .english: "Caption copied.", .japanese: "文案をコピーしました。", .traditionalChinese: "文案已複製。"],
        .shareCaptionCopied: [.simplifiedChinese: "文案已复制；如果微信等 App 没自动带上文字，可直接粘贴。", .english: "Caption copied. If WeChat or another app does not auto-fill it, paste it directly.", .japanese: "文案をコピーしました。WeChat などで自動入力されない場合は、そのまま貼り付けてください。", .traditionalChinese: "文案已複製；如果微信等 App 未自動帶上文字，可直接貼上。"],
        .savedToFavorites: [.simplifiedChinese: "已加入收藏。", .english: "Saved to favorites.", .japanese: "お気に入りに保存しました。", .traditionalChinese: "已加入收藏。"],
        .removedFromFavorites: [.simplifiedChinese: "已取消收藏。", .english: "Removed from favorites.", .japanese: "お気に入りから外しました。", .traditionalChinese: "已取消收藏。"],
        .disliked: [.simplifiedChinese: "已避开这类文案。", .english: "I’ll avoid captions like this.", .japanese: "このタイプは避けます。", .traditionalChinese: "已避開這類文案。"],
        .historyAndFavorites: [.simplifiedChinese: "历史与收藏", .english: "History & Favorites", .japanese: "履歴とお気に入り", .traditionalChinese: "歷史與收藏"],
        .allHistory: [.simplifiedChinese: "全部", .english: "All", .japanese: "すべて", .traditionalChinese: "全部"],
        .favorites: [.simplifiedChinese: "收藏", .english: "Favorites", .japanese: "お気に入り", .traditionalChinese: "收藏"],
        .historyEmpty: [.simplifiedChinese: "还没有历史记录。生成、复制或分享文案后会自动出现在这里。", .english: "No history yet. Generated, copied, and shared captions will appear here.", .japanese: "履歴はまだありません。生成、コピー、共有した文案がここに表示されます。", .traditionalChinese: "還沒有歷史記錄。生成、複製或分享文案後會自動出現在這裡。"],
        .favoritesEmpty: [.simplifiedChinese: "还没有收藏。看到喜欢的文案时点星标，就能在这里找回来。", .english: "No favorites yet. Tap the star on captions you want to keep.", .japanese: "お気に入りはまだありません。残したい文案の星をタップしてください。", .traditionalChinese: "還沒有收藏。看到喜歡的文案時點星標，就能在這裡找回來。"],
        .delete: [.simplifiedChinese: "删除", .english: "Delete", .japanese: "削除", .traditionalChinese: "刪除"],
        .preferenceTitle: [.simplifiedChinese: "你的文案偏好", .english: "Your caption preferences", .japanese: "文案の好み", .traditionalChinese: "你的文案偏好"],
        .preferenceSubtitle: [.simplifiedChinese: "这些偏好会根据复制、分享和不喜欢自动调整，当前只保存在本机。", .english: "These preferences learn from copy, share, and dislike actions. They stay on this device.", .japanese: "コピー、共有、苦手の操作から好みを学習します。データはこの端末に保存されます。", .traditionalChinese: "這些偏好會根據複製、分享和不喜歡自動調整，目前只保存在本機。"],
        .interfaceLanguage: [.simplifiedChinese: "界面语言", .english: "Interface language", .japanese: "表示言語", .traditionalChinese: "介面語言"],
        .interfaceLanguagePicker: [.simplifiedChinese: "App 界面", .english: "App interface", .japanese: "アプリ表示", .traditionalChinese: "App 介面"],
        .interfaceLanguageNote: [.simplifiedChinese: "只影响 App 按钮、设置和提示文案；生成文案语言仍在“文案语言”里单独选择。", .english: "Changes app buttons, settings, and prompts only. Generated caption language is still controlled below.", .japanese: "ボタン、設定、案内文だけを切り替えます。生成文案の言語は下の「文案言語」で設定します。", .traditionalChinese: "只影響 App 按鈕、設定和提示文案；生成文案語言仍在「文案語言」單獨選擇。"],
        .captionLanguage: [.simplifiedChinese: "文案语言", .english: "Caption language", .japanese: "文案言語", .traditionalChinese: "文案語言"],
        .generationLanguage: [.simplifiedChinese: "生成语言", .english: "Generation language", .japanese: "生成言語", .traditionalChinese: "生成語言"],
        .captionLanguageNote: [.simplifiedChinese: "只影响生成出来的文案语言。", .english: "Only changes the language of generated captions.", .japanese: "生成される文案の言語だけを変更します。", .traditionalChinese: "只影響生成出來的文案語言。"],
        .membershipMock: [.simplifiedChinese: "会员 Mock", .english: "Membership mock", .japanese: "会員 Mock", .traditionalChinese: "會員 Mock"],
        .currentLevel: [.simplifiedChinese: "当前等级", .english: "Current level", .japanese: "現在のプラン", .traditionalChinese: "目前等級"],
        .advancedStyle: [.simplifiedChinese: "高级风格", .english: "Advanced styles", .japanese: "高度なスタイル", .traditionalChinese: "高級風格"],
        .cloudEnhance: [.simplifiedChinese: "云端增强", .english: "Cloud enhancement", .japanese: "クラウド強化", .traditionalChinese: "雲端增強"],
        .watermarkRemoval: [.simplifiedChinese: "去水印", .english: "Watermark removal", .japanese: "透かし削除", .traditionalChinese: "去浮水印"],
        .available: [.simplifiedChinese: "可用", .english: "Available", .japanese: "利用可", .traditionalChinese: "可用"],
        .unavailable: [.simplifiedChinese: "未开放", .english: "Not open yet", .japanese: "未開放", .traditionalChinese: "未開放"],
        .todayUsage: [.simplifiedChinese: "今日用量", .english: "Today’s usage", .japanese: "本日の使用量", .traditionalChinese: "今日用量"],
        .captionGeneration: [.simplifiedChinese: "文案生成", .english: "Caption generation", .japanese: "文案生成", .traditionalChinese: "文案生成"],
        .basicEnhancement: [.simplifiedChinese: "基础图片美化", .english: "Basic photo enhancement", .japanese: "基本写真補正", .traditionalChinese: "基礎圖片美化"],
        .unlimited: [.simplifiedChinese: "不限", .english: "Unlimited", .japanese: "無制限", .traditionalChinese: "不限"],
        .resetUsage: [.simplifiedChinese: "重置今日用量", .english: "Reset today’s usage", .japanese: "本日の使用量をリセット", .traditionalChinese: "重置今日用量"],
        .betaUsageNote: [.simplifiedChinese: "免费版每日 100 次生成；云端增强当前仅预留本地额度和请求结构，暂不接入外部 API。", .english: "Free includes 100 generations per day. Cloud enhancement currently only reserves local quota and request structure, with no external API connected.", .japanese: "Free は1日100回生成できます。クラウド強化はローカル回数とリクエスト構造のみ予約済みで、外部 API は未接続です。", .traditionalChinese: "免費版每日 100 次生成；雲端增強目前僅預留本地額度和請求結構，暫不接入外部 API。"],
        .localAI: [.simplifiedChinese: "本机 AI", .english: "On-device AI", .japanese: "オンデバイス AI", .traditionalChinese: "本機 AI"],
        .currentStatus: [.simplifiedChinese: "当前状态", .english: "Status", .japanese: "現在の状態", .traditionalChinese: "目前狀態"],
        .preferenceLearning: [.simplifiedChinese: "偏好学习", .english: "Preference learning", .japanese: "好み学習", .traditionalChinese: "偏好學習"],
        .runningOnDevice: [.simplifiedChinese: "本机运行中", .english: "Running on device", .japanese: "端末上で実行中", .traditionalChinese: "本機運行中"],
        .localSave: [.simplifiedChinese: "本地保存", .english: "Local storage", .japanese: "ローカル保存", .traditionalChinese: "本地保存"],
        .connected: [.simplifiedChinese: "已接入", .english: "Enabled", .japanese: "接続済み", .traditionalChinese: "已接入"],
        .realPayment: [.simplifiedChinese: "真实支付", .english: "Real payments", .japanese: "実決済", .traditionalChinese: "真實支付"],
        .laterStage: [.simplifiedChinese: "后续阶段", .english: "Later stage", .japanese: "後続段階", .traditionalChinese: "後續階段"],
        .aboutSnapCopy: [.simplifiedChinese: "关于 SnapCopy", .english: "About SnapCopy", .japanese: "SnapCopy について", .traditionalChinese: "關於 SnapCopy"],
        .version: [.simplifiedChinese: "版本", .english: "Version", .japanese: "バージョン", .traditionalChinese: "版本"],
        .updateNotes: [.simplifiedChinese: "开发内容", .english: "Development notes", .japanese: "開発内容", .traditionalChinese: "開發內容"],
        .developer: [.simplifiedChinese: "开发人员", .english: "Developer", .japanese: "開発者", .traditionalChinese: "開發人員"],
        .betaTestGuide: [.simplifiedChinese: "测试说明", .english: "Beta testing notes", .japanese: "テスト説明", .traditionalChinese: "測試說明"],
        .betaTestGuideText: [.simplifiedChinese: "请重点体验选图、拍照、生成、不喜欢换一条、收藏、历史、复制、分享、多语言和本机 AI。遇到异常时，请把截图、机型、iOS 版本和复现步骤发给开发者。", .english: "Please test photo picking, camera capture, generation, dislike-to-regenerate, favorites, history, copy, share, languages, and on-device AI. For issues, send screenshots, device model, iOS version, and steps to reproduce.", .japanese: "写真選択、撮影、生成、苦手で再生成、お気に入り、履歴、コピー、共有、多言語、オンデバイス AI を重点的に確認してください。不具合はスクショ、機種、iOS バージョン、再現手順を開発者へ送ってください。", .traditionalChinese: "請重點體驗選圖、拍照、生成、不喜歡換一條、收藏、歷史、複製、分享、多語言和本機 AI。遇到異常時，請把截圖、機型、iOS 版本和重現步驟發給開發者。"],
        .feedback: [.simplifiedChinese: "测试反馈", .english: "Beta feedback", .japanese: "テストフィードバック", .traditionalChinese: "測試回饋"],
        .feedbackIntro: [.simplifiedChinese: "如果愿意帮忙测试，请把不顺手的地方、生成效果差的例子或崩溃截图发给我。", .english: "If you’re testing SnapCopy, please send awkward flows, weak caption examples, or crash screenshots.", .japanese: "テストに協力いただける場合、使いにくい点、文案が弱い例、クラッシュ画面を送ってください。", .traditionalChinese: "如果願意幫忙測試，請把不順手的地方、生成效果差的例子或崩潰截圖發給我。"],
        .copyFeedbackEmail: [.simplifiedChinese: "复制反馈邮箱", .english: "Copy feedback email", .japanese: "メールをコピー", .traditionalChinese: "複製回饋信箱"],
        .feedbackEmailCopied: [.simplifiedChinese: "反馈邮箱已复制。", .english: "Feedback email copied.", .japanese: "メールアドレスをコピーしました。", .traditionalChinese: "回饋信箱已複製。"],
        .paywallTitle: [.simplifiedChinese: "今日测试额度已用完", .english: "Today’s beta limit is used up", .japanese: "本日のテスト枠を使い切りました", .traditionalChinese: "今日測試額度已用完"],
        .paywallSubtitle: [.simplifiedChinese: "感谢你帮忙测试。文案生成额度会在明天自动恢复，基础图片美化仍可继续使用。", .english: "Thanks for helping test SnapCopy. Caption generations reset tomorrow; basic photo enhancement still works.", .japanese: "テストへのご協力ありがとうございます。文案生成枠は明日リセットされ、基本写真補正は引き続き使えます。", .traditionalChinese: "感謝你幫忙測試。文案生成額度會在明天自動恢復，基礎圖片美化仍可繼續使用。"],
        .paywallTodayCount: [.simplifiedChinese: "今日已生成", .english: "Generated today", .japanese: "本日の生成数", .traditionalChinese: "今日已生成"],
        .paywallGotIt: [.simplifiedChinese: "我知道了", .english: "Got it", .japanese: "了解", .traditionalChinese: "我知道了"],
        .paywallNavigationTitle: [.simplifiedChinese: "测试额度", .english: "Beta limit", .japanese: "テスト枠", .traditionalChinese: "測試額度"]
    ]
}
