import Foundation

struct CaptionFeatureExtractor {
    func extract(
        from caption: CaptionCandidate,
        context: CaptionGenerationContext,
        targetLanguage: CaptionLanguage
    ) -> CaptionFeatureVector {
        CaptionFeatureVector(
            scene: resolvedScene(for: caption, context: context),
            style: styleName(for: caption),
            tone: toneName(for: caption.style),
            platform: caption.platform.rawValue,
            length: caption.lengthLevel.rawValue,
            emojiLevel: caption.emojiLevel.rawValue,
            language: detectedLanguage(for: caption.text, fallback: targetLanguage),
            hashtagLevel: hashtagLevel(for: caption.text)
        )
    }

    private func resolvedScene(for caption: CaptionCandidate, context: CaptionGenerationContext) -> String {
        if let productScene = context.analysisResult?.sceneResolution.scene,
           productScene != .unknown {
            return productScene.rawValue
        }

        if let firstSceneTag = context.sceneTags.first(where: { !$0.isEmpty && $0 != "daily" }) {
            return firstSceneTag
        }

        return caption.scene.rawValue
    }

    private func styleName(for caption: CaptionCandidate) -> String {
        if caption.platform == .instagram {
            return "instagram"
        }

        return caption.style.rawValue
    }

    private func toneName(for style: CaptionStyle) -> String {
        switch style {
        case .healing:
            return "soft"
        case .humor:
            return "playful"
        case .premium:
            return "polished"
        case .xiaohongshu:
            return "lifestyle"
        case .concise:
            return "direct"
        case .poetic:
            return "poetic"
        case .daily:
            return "daily"
        }
    }

    private func detectedLanguage(for text: String, fallback: CaptionLanguage) -> String {
        if text.range(of: "[ぁ-んァ-ン]", options: .regularExpression) != nil {
            return CaptionLanguage.japanese.rawValue
        }

        let latinScalars = text.unicodeScalars.filter { scalar in
            (65...90).contains(Int(scalar.value)) || (97...122).contains(Int(scalar.value))
        }
        let cjkScalars = text.unicodeScalars.filter { scalar in
            (0x4E00...0x9FFF).contains(Int(scalar.value))
        }

        if latinScalars.count > cjkScalars.count * 2, latinScalars.count >= 8 {
            return CaptionLanguage.englishUS.rawValue
        }

        return fallback.rawValue
    }

    private func hashtagLevel(for text: String) -> String {
        let count = text.filter { $0 == "#" }.count

        switch count {
        case 0:
            return "none"
        case 1...2:
            return "low"
        default:
            return "medium"
        }
    }
}
