import UIKit

#if canImport(FoundationModels)
import FoundationModels
#endif

struct CaptionGenerationPrompt: Equatable {
    let instructions: String
    let prompt: String
    let contextJSON: String
}

enum CaptionPromptDetail {
    case full
    case compact
}

struct CaptionGenerationPromptBuilder {
    func makePrompt(
        context: CaptionGenerationContext,
        preference: UserPreference,
        detail: CaptionPromptDetail = .full
    ) -> CaptionGenerationPrompt {
        let language = preference.preferredCaptionLanguage
        let contextPayload = CaptionContextBuilder().build(context: context, preference: preference)
        let contextJSON = detail == .full ? contextPayload.prettyPrintedJSON : contextPayload.compactJSON
        let strategyBlock = CaptionStrategyLibrary().promptBlock(
            context: context,
            preference: preference,
            compact: detail == .compact
        )
        let instructions = """
        You are SnapCopy's social caption assistant.
        Use only the provided photo_context_json as source of truth.
        Write natural, varied captions for sharing the photo.
        Output every caption in \(language.promptName), unless briefly quoting OCR text from the image.
        Do not invent objects, people, food, brands, locations, or text that are not supported by the JSON.
        Prefer concrete visual evidence over broad scene labels.
        The writing should sound like a thoughtful adult posting on social media: restrained, specific, and conversational.
        """

        let detailRules: String
        if context.hasImageDetails {
            detailRules = """
            Image-detail rules:
            - photo_context_json contains concrete visual cues. Use these cues as anchors, not just sceneTags.
            - If image.captionFocus is present, treat it as the main writing anchor. At least 4 of the 5 captions must reflect that focus.
            - If image.relationshipCues are present, do not flatten the photo into only the primary scene. Use the relationship between visible objects.
            - If image.actionCues are present, use them as soft scene interpretation. Phrase uncertain actions naturally and avoid claiming exact facts beyond the visible cues.
            - image.subjectCues and image.objectCues are the most important concrete anchors. Prefer them over broad labels like daily, pet, food, or work.
            - If image.mustMentionCues has two or more items, every caption should include at least two of those cues or one cue plus a relationship cue.
            - At least 3 of the 5 captions must visibly reflect one grounded detail or atmosphere cue from captionFocus, subjectCues, objectCues, actionCues, mustMentionCues, visionLabels, ocrTexts, featureFlags, or visualTraits.
            - Across the batch, use at least two different cue types when present: object/label, OCR text, light/color/framing, or mood.
            - Give each option a different angle. Do not repeat the same caption text, opening phrase, rhythm, or structure. No two captions may share more than half their wording.
            - Avoid generic scene-label templates unless they are strengthened by a concrete detail from the JSON.
            - Follow image.avoidUnsupportedClaims strictly.
            """
        } else {
            detailRules = """
            Image-detail rules:
            - photo_context_json has little visual evidence. Keep captions broadly applicable.
            - Do not invent specific objects, people, places, food, text, brands, or locations.
            - Give each option a different angle. Do not repeat the same caption text, opening phrase, rhythm, or structure. No two captions may share more than half their wording.
            """
        }

        if detail == .compact {
            let prompt = """
            Generate exactly 5 distinct caption options from this JSON.

            photo_context_json:
            \(contextJSON)

            Required:
            - Output every caption in \(language.promptName).
            - Use image.captionFocus, mustMentionCues, relationshipCues, visualTraits, OCR, and resolvedScene as grounded evidence.
            - Do not invent objects, exact food names, brands, places, emotions, or text not supported by the JSON.
            - Follow generation.platformGuidance and generation.lengthGuidance.
            - Do not put style, platform, lengthLevel, emojiLevel, scene, JSON, labels, OCR, confidence, or metadata inside caption text.

            \(strategyBlock)

            Writing:
            - Sound like a thoughtful adult social caption: concrete, restrained, specific, conversational.
            - Avoid empty phrases like 好可爱, 很温暖, 很幸福, 小确幸, 今日份, 记录一下, 值得留下, 治愈 unless a concrete visual cue makes it necessary.
            - Make the five captions meaningfully different.
            - Keep emoji light.
            """

            return CaptionGenerationPrompt(instructions: instructions, prompt: prompt, contextJSON: contextJSON)
        }

        let prompt = """
        Generate 5 caption options from this JSON.

        photo_context_json:
        \(contextJSON)

        Required interpretation:
        - Main scene: image.resolvedScene.scene.
        - Scene confidence: image.resolvedScene.confidence.
        - Sub-scene and signals explain why the scene was chosen.
        - image.captionFocus is the strongest photo-specific writing anchor.
        - image.mustMentionCues are concrete details that should appear naturally in captions.
        - image.relationshipCues explain important object combinations.
        - image.subjectCues, image.objectCues, image.actionCues, and image.atmosphereCues are enhanced local interpretation from Vision label combinations.
        - image.semanticSummary explains the local image-understanding interpretation in plain language.
        - image.avoidUnsupportedClaims are hard limits. Do not contradict them.
        - visionLabels, ocrTexts, featureFlags, and visualTraits are the grounded photo evidence.
        - generation.platformGuidance and generation.lengthGuidance define the target platform and length.
        - generation.preferredStyles, likedPhrases, avoidStyles, avoidPhrases, sentenceShape, emojiPreference, and punctuationPreference are user taste signals.
        - If generation.stylePreferenceWarning is present, follow the warning before avoidStyles.

        \(strategyBlock)

        \(detailRules)

        Mature writing rules:
        - Write like an adult with taste, not like a school essay, greeting card, diary homework, or childish compliment.
        - Avoid empty praise and generic phrases such as "好可爱", "很温暖", "很幸福", "小确幸", "今日份", "记录一下", "值得留下", "让人感到", "美好时光", "治愈", and similar phrases unless a concrete visual cue makes them necessary.
        - Prefer a small point of view, understated humor, or a precise observation over broad emotional labels.
        - Use concrete nouns and verbs from the photo. Do not rely on words like beautiful, warm, happy, cute, lovely, healing, or vibe unless paired with a visible detail.
        - When image.actionCues show a distinctive interaction, make that interaction the angle instead of writing a generic scene caption.
        - Keep emoji light. Do not use more than one emoji unless generation.emojiPreference strongly asks for it.
        - For humor, use dry or understated humor, not childish cuteness.
        - For premium style, use clean rhythm and visual detail, not luxury clichés.

        Generation rules:
        - Every caption text must be written in \(language.promptName).
        - Use varied tones across the five options: healing, humor, premium, xiaohongshu, concise.
        - The five captions must be meaningfully different. If one candidate repeats another candidate's core wording or structure, rewrite it.
        - Every candidate should target generation.platform unless it is general.
        - Set each candidate's platform field to generation.platform.
        At least 4 of the 5 candidates should follow the selected caption length. Set each candidate's lengthLevel field to "\(preference.preferredLengthLevel.rawValue)" unless a small variation is necessary for variety.
        - If scene confidence is below 0.75, keep captions grounded and avoid over-specific claims.
        - If scene is unknown but visual evidence exists, write from the evidence instead of using generic daily captions.
        - Use OCR as context or mood. Quote visible text only when it feels natural.
        - At least 4 of the 5 captions should visibly reflect image.captionFocus when present.
        - At least 3 of the 5 captions should visibly reflect a concrete visual cue when labels, OCR, or visual traits are present.
        - If preferredStyles are present, at least 3 of the 5 captions should lean toward those styles while still keeping variety.
        - Use Caption strategy library examples as writing references, not as text to copy.
        - Do not use avoidStyles or avoidPhrases unless unavoidable.
        - The text field must contain only the final caption. Do not include style, platform, lengthLevel, emojiLevel, scene, field names, enum values, JSON, bullets, or metadata inside text.
        - Do not mention JSON, labels, OCR, confidence, model analysis, recommendation, or AI in the caption text.
        """

        return CaptionGenerationPrompt(instructions: instructions, prompt: prompt, contextJSON: contextJSON)
    }
}

final class CaptionGenerationService: CaptionService {
    private let mockService = MockCaptionService()

    func localAIStatus() -> LocalAIAvailabilityStatus {
        LocalAIAvailabilityDetector.currentStatus()
    }

    func generateCaptions(
        for image: UIImage,
        context: CaptionGenerationContext,
        preference: UserPreference
    ) async throws -> CaptionGenerationResult {
        let status = localAIStatus()
        let generationPrompt = CaptionGenerationPromptBuilder().makePrompt(context: context, preference: preference)

        guard status == .available else {
            let mockResult = try await mockService.generateCaptions(for: image, context: context, preference: preference)
            return CaptionGenerationResult(
                candidates: mockResult.candidates,
                mode: .mock,
                statusMessage: "\(status.detail) 已回退到基础文案。",
                debugInfo: mockResult.debugInfo ?? CaptionGenerationDebugInfo(
                    contextJSON: generationPrompt.contextJSON,
                    foundationPrompt: generationPrompt.prompt,
                    rawFoundationResult: "Local AI unavailable: \(status.detail)"
                )
            )
        }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            do {
                let output = try await generateWithFoundationModels(
                    context: context,
                    preference: preference,
                    generationPrompt: generationPrompt
                )
                guard !output.candidates.isEmpty else {
                    throw CaptionGenerationServiceError.emptyLocalAIResult
                }

                return CaptionGenerationResult(
                    candidates: output.candidates,
                    mode: .localAI,
                    statusMessage: "已使用 Apple Foundation Models 生成。\(contextStatusText(context))\(preferenceStatusText(preference, context: context))",
                    debugInfo: CaptionGenerationDebugInfo(
                        contextJSON: output.prompt.contextJSON,
                        foundationPrompt: output.prompt.prompt,
                        rawFoundationResult: output.rawResult
                    )
                )
            } catch {
                let mockResult = try await mockService.generateCaptions(for: image, context: context, preference: preference)
                return CaptionGenerationResult(
                    candidates: mockResult.candidates,
                    mode: .mock,
                    statusMessage: "\(localAIErrorMessage(for: error)) 已回退到基础文案。",
                    debugInfo: CaptionGenerationDebugInfo(
                        contextJSON: generationPrompt.contextJSON,
                        foundationPrompt: generationPrompt.prompt,
                        rawFoundationResult: "Foundation Models error: \(error)\n\nMock fallback:\n\(mockResult.candidates.map(\.text).joined(separator: "\n"))"
                    )
                )
            }
        }
        #endif

        let mockResult = try await mockService.generateCaptions(for: image, context: context, preference: preference)
        return CaptionGenerationResult(
            candidates: mockResult.candidates,
            mode: .mock,
            statusMessage: "当前系统不支持本机 AI，已回退到基础文案。",
            debugInfo: mockResult.debugInfo ?? CaptionGenerationDebugInfo(
                contextJSON: generationPrompt.contextJSON,
                foundationPrompt: generationPrompt.prompt,
                rawFoundationResult: "Foundation Models SDK unavailable."
            )
        )
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func generateWithFoundationModels(
        context: CaptionGenerationContext,
        preference: UserPreference,
        generationPrompt: CaptionGenerationPrompt
    ) async throws -> LocalAIGenerationOutput {
        do {
            return try await generateWithFoundationModelsOnce(
                context: context,
                preference: preference,
                generationPrompt: generationPrompt,
                rawPrefix: nil
            )
        } catch {
            guard shouldRetryWithCompactPrompt(error) else {
                throw error
            }

            let compactPrompt = CaptionGenerationPromptBuilder().makePrompt(
                context: context,
                preference: preference,
                detail: .compact
            )
            return try await generateWithFoundationModelsOnce(
                context: context,
                preference: preference,
                generationPrompt: compactPrompt,
                rawPrefix: "Full prompt failed: \(error)\nRetried with compact prompt."
            )
        }
    }

    @available(iOS 26.0, *)
    private func generateWithFoundationModelsOnce(
        context: CaptionGenerationContext,
        preference: UserPreference,
        generationPrompt: CaptionGenerationPrompt,
        rawPrefix: String?
    ) async throws -> LocalAIGenerationOutput {
        let session = LanguageModelSession(instructions: generationPrompt.instructions)
        let options = GenerationOptions(
            sampling: .random(top: 30),
            temperature: 0.8,
            maximumResponseTokens: 700
        )
        let response = try await session.respond(
            to: generationPrompt.prompt,
            generating: LocalAICaptionBatch.self,
            includeSchemaInPrompt: true,
            options: options
        )

        let fallbackCandidates = mockService.fallbackCandidates(context: context, preference: preference)
        let candidates = CaptionCandidateDeduplicator().uniqueCandidates(
            response.content.candidates(fallbackScene: context.primaryScene),
            fallbackCandidates: fallbackCandidates,
            limit: 10
        )
        let refinedCandidates = Array(CaptionQualityEvaluator().ranked(candidates, context: context).prefix(5))

        if refinedCandidates.isEmpty {
            throw CaptionGenerationServiceError.emptyLocalAIResult
        }

        return LocalAIGenerationOutput(
            candidates: refinedCandidates,
            rawResult: [rawPrefix, String(describing: response.content)]
                .compactMap { $0 }
                .joined(separator: "\n\n"),
            prompt: generationPrompt
        )
    }

    @available(iOS 26.0, *)
    private func shouldRetryWithCompactPrompt(_ error: Error) -> Bool {
        if error is CaptionGenerationServiceError {
            return true
        }

        if let generationError = error as? LanguageModelSession.GenerationError {
            switch generationError {
            case .exceededContextWindowSize, .decodingFailure, .unsupportedGuide:
                return true
            case .assetsUnavailable, .guardrailViolation, .refusal, .unsupportedLanguageOrLocale, .rateLimited, .concurrentRequests:
                return false
            @unknown default:
                return false
            }
        }

        return false
    }

    @available(iOS 26.0, *)
    private func localAIErrorMessage(for error: Error) -> String {
        if let generationError = error as? LanguageModelSession.GenerationError {
            switch generationError {
            case .exceededContextWindowSize:
                return "本机 AI 上下文过长。"
            case .assetsUnavailable:
                return "本机 AI 模型资源暂不可用，可能还在准备。"
            case .guardrailViolation, .refusal:
                return "本机 AI 拒绝了这次生成。"
            case .unsupportedGuide:
                return "本机 AI 不支持当前输出约束。"
            case .unsupportedLanguageOrLocale:
                return "本机 AI 当前语言或地区暂不支持这次生成。"
            case .decodingFailure:
                return "本机 AI 输出结构解析失败。"
            case .rateLimited:
                return "本机 AI 请求太频繁。"
            case .concurrentRequests:
                return "本机 AI 上一次请求还没结束。"
            @unknown default:
                return "本机 AI 遇到未知生成错误。"
            }
        }

        if error is CaptionGenerationServiceError {
            return "本机 AI 没有返回可用文案。"
        }

        return "本机 AI 生成失败。"
    }
    #endif

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

private enum CaptionGenerationServiceError: Error {
    case emptyLocalAIResult
}

private struct LocalAIGenerationOutput {
    let candidates: [CaptionCandidate]
    let rawResult: String
    let prompt: CaptionGenerationPrompt
}

struct CaptionCandidateDeduplicator {
    private static let ignoredCharacters = CharacterSet.whitespacesAndNewlines
        .union(CharacterSet(charactersIn: "，。！？、；：,.!?;:\"“”‘’（）()[]【】《》<>~～…"))

    func uniqueCandidates(
        _ candidates: [CaptionCandidate],
        fallbackCandidates: [CaptionCandidate] = [],
        limit: Int = 5
    ) -> [CaptionCandidate] {
        var result: [CaptionCandidate] = []
        var seenKeys: Set<String> = []

        appendUniqueCandidates(candidates, to: &result, seenKeys: &seenKeys, limit: limit)
        appendUniqueCandidates(fallbackCandidates, to: &result, seenKeys: &seenKeys, limit: limit)

        return result
    }

    private func appendUniqueCandidates(
        _ candidates: [CaptionCandidate],
        to result: inout [CaptionCandidate],
        seenKeys: inout Set<String>,
        limit: Int
    ) {
        for candidate in candidates where result.count < limit {
            let key = duplicateKey(for: candidate.text)

            guard !key.isEmpty, !seenKeys.contains(key) else {
                continue
            }

            seenKeys.insert(key)
            result.append(candidate)
        }
    }

    private func duplicateKey(for text: String) -> String {
        String(
            text
                .lowercased()
                .unicodeScalars
                .filter { !Self.ignoredCharacters.contains($0) }
        )
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable(description: "A batch of five distinct SnapCopy caption candidates with different wording and angles.")
private struct LocalAICaptionBatch {
    @Guide(description: "Exactly five caption candidates. Each candidate should be meaningfully different from the others.")
    let captions: [LocalAICaption]

    func candidates(fallbackScene: SceneType) -> [CaptionCandidate] {
        captions.prefix(5).compactMap { caption in
            caption.candidate(fallbackScene: fallbackScene)
        }
    }
}

@available(iOS 26.0, *)
@Generable(description: "One SnapCopy caption candidate.")
private struct LocalAICaption {
    @Guide(description: "Caption text in the requested output language. Anchor it in captionFocus, mustMentionCues, relationshipCues, visionLabels, and visualTraits from the JSON. Write like a restrained adult social caption, not a childish compliment or school essay. Do not invent visual details that were not provided.")
    let text: String

    @Guide(description: "One of: healing, humor, premium, xiaohongshu, concise, poetic, daily.")
    let style: String

    @Guide(description: "One of: general, wechat, xiaohongshu, instagram, x.")
    let platform: String

    @Guide(description: "One of: short, medium, long.")
    let lengthLevel: String

    @Guide(description: "One of: none, light, medium.")
    let emojiLevel: String

    @Guide(description: "One of: food, street, travel, pet, work, daily, unknown.")
    let scene: String

    func candidate(fallbackScene: SceneType) -> CaptionCandidate? {
        guard let sanitizedText = CaptionTextSanitizer().sanitizedText(from: text) else {
            return nil
        }

        return CaptionCandidate(
            text: sanitizedText,
            style: CaptionStyle(rawValue: style) ?? .daily,
            platform: SocialPlatform(rawValue: platform) ?? .general,
            lengthLevel: LengthLevel(rawValue: lengthLevel) ?? .medium,
            emojiLevel: EmojiLevel(rawValue: emojiLevel) ?? .none,
            scene: SceneType(rawValue: scene) ?? fallbackScene
        )
    }
}
#endif
