import Foundation

enum ShareCardTemplate: String, Codable, CaseIterable, Identifiable {
    case softBlush
    case cleanWhite
    case editorial

    var id: String { rawValue }

    func displayName(language: AppLanguage) -> String {
        switch (language, self) {
        case (.simplifiedChinese, .softBlush):
            "柔和粉色"
        case (.simplifiedChinese, .cleanWhite):
            "清透白"
        case (.simplifiedChinese, .editorial):
            "杂志感"
        case (.english, .softBlush):
            "Soft blush"
        case (.english, .cleanWhite):
            "Clean white"
        case (.english, .editorial):
            "Editorial"
        case (.japanese, .softBlush):
            "やわらかピンク"
        case (.japanese, .cleanWhite):
            "クリアホワイト"
        case (.japanese, .editorial):
            "雑誌風"
        case (.traditionalChinese, .softBlush):
            "柔和粉色"
        case (.traditionalChinese, .cleanWhite):
            "清透白"
        case (.traditionalChinese, .editorial):
            "雜誌感"
        }
    }

    func description(language: AppLanguage) -> String {
        switch (language, self) {
        case (.simplifiedChinese, .softBlush):
            "圆润、温柔，适合朋友圈和日常分享。"
        case (.simplifiedChinese, .cleanWhite):
            "留白更多，照片和文案更清爽。"
        case (.simplifiedChinese, .editorial):
            "更像封面卡片，适合小红书和 Instagram。"
        case (.english, .softBlush):
            "Rounded and warm for daily sharing."
        case (.english, .cleanWhite):
            "More whitespace with a cleaner caption layout."
        case (.english, .editorial):
            "Cover-like composition for Xiaohongshu and Instagram."
        case (.japanese, .softBlush):
            "丸みのある温かい日常向けデザイン。"
        case (.japanese, .cleanWhite):
            "余白を活かしたすっきりしたレイアウト。"
        case (.japanese, .editorial):
            "表紙のように見せる投稿向けカード。"
        case (.traditionalChinese, .softBlush):
            "圓潤、溫柔，適合朋友圈和日常分享。"
        case (.traditionalChinese, .cleanWhite):
            "留白更多，照片和文案更清爽。"
        case (.traditionalChinese, .editorial):
            "更像封面卡片，適合小紅書和 Instagram。"
        }
    }
}

struct ShareCardTemplateRepository {
    let templates = ShareCardTemplate.allCases

    func fallbackTemplate() -> ShareCardTemplate {
        .softBlush
    }
}
