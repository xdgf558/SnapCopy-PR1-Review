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
            "柔和圆润的日常风格，让照片和文字看起来更温暖。"
        case (.simplifiedChinese, .cleanWhite):
            "清爽留白，突出照片本身，适合干净自然的分享。"
        case (.simplifiedChinese, .editorial):
            "更有封面感的排版，让内容看起来更精致。"
        case (.english, .softBlush):
            "A soft, rounded style that makes everyday moments feel warmer."
        case (.english, .cleanWhite):
            "Clean spacing that keeps the photo clear and the caption easy to read."
        case (.english, .editorial):
            "A polished cover-style layout for a more refined share card."
        case (.japanese, .softBlush):
            "やわらかく丸みのある、日常の一枚を温かく見せるスタイル。"
        case (.japanese, .cleanWhite):
            "すっきりした余白で、写真と文案を読みやすく整えます。"
        case (.japanese, .editorial):
            "表紙のような構成で、投稿をより上品に見せるカード。"
        case (.traditionalChinese, .softBlush):
            "柔和圓潤的日常風格，讓照片和文字看起來更溫暖。"
        case (.traditionalChinese, .cleanWhite):
            "清爽留白，突出照片本身，適合乾淨自然的分享。"
        case (.traditionalChinese, .editorial):
            "更有封面感的排版，讓內容看起來更精緻。"
        }
    }
}

struct ShareCardTemplateRepository {
    let templates = ShareCardTemplate.allCases

    func fallbackTemplate() -> ShareCardTemplate {
        .softBlush
    }
}
