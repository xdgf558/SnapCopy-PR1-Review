import Foundation

struct CaptionSampleLibraryItem: Identifiable, Codable, Equatable {
    let id: UUID
    var text: String
    var originalText: String
    var scene: SceneType
    var style: CaptionStyle
    var platform: SocialPlatform
    var lengthLevel: LengthLevel
    var emojiLevel: EmojiLevel
    var language: CaptionLanguage
    var qualityScore: Double
    var qualityReasons: [String]
    var useCount: Int
    var editWasApplied: Bool
    var createdAt: Date
    var updatedAt: Date
}

struct CaptionSampleDecision: Equatable {
    enum Action: Equatable {
        case kept
        case updated
        case rejected
        case removedWeakDuplicate
    }

    let action: Action
    let score: Double
    let reasons: [String]
}

final class CaptionSampleLibraryStore {
    private let storageKey = "snapcopy.captionSampleLibrary"
    private let maxSamples = 180
    private let minimumKeepScore = 0.64
    private let weakDuplicateScore = 0.52
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let strategyLibrary = CaptionStrategyLibrary()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func loadSamples() -> [CaptionSampleLibraryItem] {
        guard let data = userDefaults.data(forKey: storageKey),
              let samples = try? decoder.decode([CaptionSampleLibraryItem].self, from: data) else {
            return []
        }

        return sorted(samples)
    }

    func topSamples(
        for context: CaptionGenerationContext,
        language: CaptionLanguage,
        platform: SocialPlatform,
        limit: Int
    ) -> [CaptionSampleLibraryItem] {
        let scene = strategyLibrary.resolvedScene(for: context)

        return loadSamples()
            .filter { sample in
                sample.language == language &&
                (sample.scene == scene || sample.scene == .daily || scene == .unknown) &&
                (sample.platform == platform || sample.platform == .general || platform == .general)
            }
            .sorted { lhs, rhs in
                sampleRank(lhs, scene: scene, platform: platform) > sampleRank(rhs, scene: scene, platform: platform)
            }
            .prefix(limit)
            .map { $0 }
    }

    @discardableResult
    func recordSharedCaption(
        original: CaptionCandidate,
        finalCaption: CaptionCandidate,
        context: CaptionGenerationContext,
        preference: UserPreference,
        editSummary: CaptionEditSummary?
    ) -> CaptionSampleDecision {
        let summary = editSummary ?? CaptionEditSummary(originalText: original.text, finalText: finalCaption.text)
        let assessment = strategyLibrary.qualityScore(
            text: finalCaption.text,
            context: context,
            preference: preference,
            editSummary: summary.wasEdited ? summary : nil
        )
        var samples = loadSamples()
        let textKey = Self.key(for: finalCaption.text)
        let now = Date()

        if assessment.score < minimumKeepScore {
            if assessment.score <= weakDuplicateScore {
                let oldCount = samples.count
                samples.removeAll { Self.key(for: $0.text) == textKey }
                if samples.count != oldCount {
                    save(samples)
                    return CaptionSampleDecision(
                        action: .removedWeakDuplicate,
                        score: assessment.score,
                        reasons: assessment.reasons
                    )
                }
            }

            return CaptionSampleDecision(
                action: .rejected,
                score: assessment.score,
                reasons: assessment.reasons
            )
        }

        if let index = samples.firstIndex(where: { Self.key(for: $0.text) == textKey }) {
            samples[index].originalText = original.text
            samples[index].scene = strategyLibrary.resolvedScene(for: context)
            samples[index].style = finalCaption.style
            samples[index].platform = finalCaption.platform
            samples[index].lengthLevel = finalCaption.lengthLevel
            samples[index].emojiLevel = finalCaption.emojiLevel
            samples[index].language = preference.preferredCaptionLanguage
            samples[index].qualityScore = max(samples[index].qualityScore, assessment.score)
            samples[index].qualityReasons = assessment.reasons
            samples[index].useCount += 1
            samples[index].editWasApplied = samples[index].editWasApplied || summary.wasEdited
            samples[index].updatedAt = now
            save(pruned(samples))
            return CaptionSampleDecision(
                action: .updated,
                score: assessment.score,
                reasons: assessment.reasons
            )
        }

        samples.append(
            CaptionSampleLibraryItem(
                id: UUID(),
                text: finalCaption.text.trimmingCharacters(in: .whitespacesAndNewlines),
                originalText: original.text,
                scene: strategyLibrary.resolvedScene(for: context),
                style: finalCaption.style,
                platform: finalCaption.platform,
                lengthLevel: finalCaption.lengthLevel,
                emojiLevel: finalCaption.emojiLevel,
                language: preference.preferredCaptionLanguage,
                qualityScore: assessment.score,
                qualityReasons: assessment.reasons,
                useCount: 1,
                editWasApplied: summary.wasEdited,
                createdAt: now,
                updatedAt: now
            )
        )
        save(pruned(samples))

        return CaptionSampleDecision(
            action: .kept,
            score: assessment.score,
            reasons: assessment.reasons
        )
    }

    func clear() {
        userDefaults.removeObject(forKey: storageKey)
    }

    static func key(for text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .filter { !$0.isWhitespace }
    }

    private func pruned(_ samples: [CaptionSampleLibraryItem]) -> [CaptionSampleLibraryItem] {
        var bestByText: [String: CaptionSampleLibraryItem] = [:]

        for sample in samples where sample.qualityScore >= minimumKeepScore {
            let key = Self.key(for: sample.text)
            if let existing = bestByText[key] {
                bestByText[key] = sampleRank(sample, scene: sample.scene, platform: sample.platform) >
                    sampleRank(existing, scene: existing.scene, platform: existing.platform)
                    ? sample
                    : existing
            } else {
                bestByText[key] = sample
            }
        }

        return sorted(Array(bestByText.values))
            .prefix(maxSamples)
            .map { $0 }
    }

    private func sorted(_ samples: [CaptionSampleLibraryItem]) -> [CaptionSampleLibraryItem] {
        samples.sorted { lhs, rhs in
            if lhs.qualityScore != rhs.qualityScore {
                return lhs.qualityScore > rhs.qualityScore
            }

            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private func sampleRank(
        _ sample: CaptionSampleLibraryItem,
        scene: SceneType,
        platform: SocialPlatform
    ) -> Double {
        var score = sample.qualityScore
        if sample.scene == scene {
            score += 0.12
        }
        if sample.platform == platform {
            score += 0.08
        }
        score += min(0.08, Double(sample.useCount) * 0.01)
        if sample.editWasApplied {
            score += 0.05
        }
        return score
    }

    private func save(_ samples: [CaptionSampleLibraryItem]) {
        guard let data = try? encoder.encode(sorted(samples)) else {
            return
        }

        userDefaults.set(data, forKey: storageKey)
    }
}
