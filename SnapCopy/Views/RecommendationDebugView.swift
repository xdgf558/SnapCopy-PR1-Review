import SwiftUI

struct RecommendationDebugView: View {
    let result: CaptionRecommendationResult?
    let feedbackEvents: [RecommendationFeedbackEvent]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let result {
                        summarySection(result)
                        filterSection(result.recommendedFilter)
                        captionScoresSection(result.rankedCaptions)
                        preferenceSection(result.preferenceSnapshot)
                    } else {
                        Text("还没有推荐结果。请先选择照片并生成文案。")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }

                    feedbackSection(feedbackEvents)
                }
                .padding(18)
            }
            .background(SnapCopyTheme.appBackground.ignoresSafeArea())
            .navigationTitle("推荐调试")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    private func summarySection(_ result: CaptionRecommendationResult) -> some View {
        debugCard(title: "最终排序") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(result.rankedCaptions.enumerated()), id: \.element.id) { index, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(scoreText(item.score))
                                    .font(.caption.monospacedDigit().weight(.semibold))
                                    .foregroundStyle(SnapCopyTheme.rose)

                                if item.isExploration {
                                    Text("探索")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(SnapCopyTheme.plum, in: Capsule())
                                }
                            }

                            Text(item.candidate.text)
                                .font(.footnote)
                                .foregroundStyle(SnapCopyTheme.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private func filterSection(_ recommendation: FilterRecommendation) -> some View {
        debugCard(title: "滤镜推荐") {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(recommendation.preset.displayName) · \(scoreText(recommendation.score))")
                    .font(.subheadline.weight(.semibold))

                ForEach(recommendation.reasons, id: \.self) { reason in
                    Text("• \(reason)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func captionScoresSection(_ captions: [ScoredCaptionRecommendation]) -> some View {
        debugCard(title: "每条文案得分来源") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(captions) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.candidate.text)
                            .font(.footnote.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)

                        featureGrid(item.features)

                        ForEach(item.scoreComponents) { component in
                            HStack {
                                Text(component.label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(scoreText(component.value))
                                    .font(.caption.monospacedDigit())
                            }
                            Text(component.reason)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .background(SnapCopyTheme.controlBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
    }

    private func preferenceSection(_ preference: RecommendationPreferenceProfile) -> some View {
        debugCard(title: "当前偏好权重") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(preference.weights.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                    HStack {
                        Text(key)
                            .font(.caption)
                        Spacer()
                        Text(String(format: "%.2f", value))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(value >= 0.5 ? SnapCopyTheme.sage : SnapCopyTheme.rose)
                    }
                }
            }
        }
    }

    private func feedbackSection(_ events: [RecommendationFeedbackEvent]) -> some View {
        debugCard(title: "最近反馈与权重变化") {
            if events.isEmpty {
                Text("还没有行为反馈。复制、分享、收藏或点击不喜欢后，这里会出现 reward。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(events.suffix(10).reversed()) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(event.action.kind.rawValue)
                                    .font(.caption.weight(.semibold))
                                Spacer()
                                if let dwellSeconds = event.dwellSeconds {
                                    Text("\(String(format: "%.1f", dwellSeconds))s")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                Text(scoreText(event.rewardScore))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(event.rewardScore >= 0 ? SnapCopyTheme.sage : SnapCopyTheme.rose)
                            }

                            Text(event.features.learningKeys.joined(separator: ", "))
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            if event.isExploration {
                                Text("探索文案反馈：学习率更高")
                                    .font(.caption2)
                                    .foregroundStyle(SnapCopyTheme.plum)
                            }

                            if let editSummary = event.editSummary {
                                Text("发布前编辑：\(editSummary.characterDelta >= 0 ? "+" : "")\(editSummary.characterDelta) 字，emoji \(editSummary.emojiDelta >= 0 ? "+" : "")\(editSummary.emojiDelta)")
                                    .font(.caption2)
                                    .foregroundStyle(SnapCopyTheme.rose)

                                Text("最终文案：\(editSummary.finalText)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                        }
                    }
                }
            }
        }
    }

    private func featureGrid(_ features: CaptionFeatureVector) -> some View {
        let rows = [
            "scene: \(features.scene)",
            "style: \(features.style)",
            "tone: \(features.tone)",
            "platform: \(features.platform)",
            "length: \(features.length)",
            "emoji: \(features.emojiLevel)",
            "language: \(features.language)",
            "hashtag: \(features.hashtagLevel)"
        ]

        return Text(rows.joined(separator: " · "))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func debugCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(SnapCopyTheme.primaryText)

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SnapCopyTheme.cardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(SnapCopyTheme.hairline, lineWidth: 1)
        }
    }

    private func scoreText(_ value: Double) -> String {
        String(format: "%+.3f", value)
    }
}
