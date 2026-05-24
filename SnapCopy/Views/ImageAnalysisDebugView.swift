import SwiftUI

struct ImageAnalysisDebugView: View {
    let analysisResult: ImageAnalysisResult?
    let foundationPrompt: String
    let rawFoundationResult: String
    let latestMetricRecord: ImageRecognitionMetricRecord?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let analysisResult {
                        sceneSection(analysisResult)
                        customModelSection(analysisResult.customSceneClassification)
                        manualSelectionSection(analysisResult)
                        metricSection(latestMetricRecord)
                        semanticSection(analysisResult.semanticSummary)
                        featureSection(analysisResult.featureFlags)
                        labelsSection(analysisResult.visionLabels)
                        ocrSection(analysisResult.recognizedTexts)
                    } else {
                        debugCard {
                            Text("还没有照片分析结果。请先选择一张照片。")
                                .font(.body)
                                .foregroundStyle(SnapCopyTheme.secondaryText)
                        }
                    }

                    textSection(title: "传给 Foundation Models 的完整 Prompt", text: foundationPrompt)
                    textSection(title: "Foundation Models 原始返回", text: rawFoundationResult)
                    validationChecklist
                }
                .padding(16)
            }
            .background(SnapCopyTheme.appBackground)
            .navigationTitle("照片理解诊断")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func sceneSection(_ result: ImageAnalysisResult) -> some View {
        debugCard {
            VStack(alignment: .leading, spacing: 10) {
                debugTitle("App 推断场景")

                LabeledContent("scene", value: result.sceneResolution.scene.displayName)
                LabeledContent("raw", value: result.sceneResolution.scene.rawValue)
                LabeledContent("subScene", value: result.sceneResolution.subScene ?? "none")
                LabeledContent("confidence", value: confidenceText(result.sceneResolution.confidence))
                LabeledContent("analysisLatency", value: "\(Int(result.analysisLatencyMs.rounded()))ms")

                if !result.sceneResolution.topCandidates.isEmpty {
                    Text("top 3 scene candidates")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SnapCopyTheme.secondaryText)

                    ForEach(result.sceneResolution.topCandidates) { candidate in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(candidate.scene.rawValue)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(SnapCopyTheme.primaryText)

                                Spacer()

                                Text("\(candidate.source.rawValue) / \(confidenceText(candidate.confidence))")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(SnapCopyTheme.rose)
                            }

                            if !candidate.explanation.isEmpty {
                                Text(candidate.explanation)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(SnapCopyTheme.secondaryText)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }

                if !result.sceneResolution.signals.isEmpty {
                    Text("signals")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SnapCopyTheme.secondaryText)

                    Text(result.sceneResolution.signals.joined(separator: "\n"))
                        .font(.caption.monospaced())
                        .foregroundStyle(SnapCopyTheme.primaryText)
                        .textSelection(.enabled)
                }

                if !result.sceneResolution.fusionExplanation.isEmpty {
                    Text("fusion explanation")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SnapCopyTheme.secondaryText)

                    Text(result.sceneResolution.fusionExplanation)
                        .font(.caption.monospaced())
                        .foregroundStyle(SnapCopyTheme.primaryText)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private func customModelSection(_ result: CustomSceneClassificationResult) -> some View {
        debugCard {
            VStack(alignment: .leading, spacing: 10) {
                debugTitle("Core ML 模型 Top-3")

                LabeledContent("status", value: result.status.rawValue)
                LabeledContent("latency", value: "\(Int(result.latencyMs.rounded()))ms")

                Text(result.explanation)
                    .font(.caption)
                    .foregroundStyle(SnapCopyTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if result.predictions.isEmpty {
                    Text("当前没有自定义模型预测，系统会继续使用 Vision + OCR + rules。")
                        .font(.caption)
                        .foregroundStyle(SnapCopyTheme.secondaryText)
                } else {
                    ForEach(result.predictions) { prediction in
                        HStack {
                            Text(prediction.scene.rawValue)
                                .font(.caption.monospaced())
                                .foregroundStyle(SnapCopyTheme.primaryText)

                            Spacer()

                            Text(confidenceText(prediction.confidence))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(SnapCopyTheme.rose)
                        }
                    }
                }
            }
        }
    }

    private func manualSelectionSection(_ result: ImageAnalysisResult) -> some View {
        debugCard {
            VStack(alignment: .leading, spacing: 10) {
                debugTitle("置信度与手动选择")

                LabeledContent("finalScene", value: result.sceneResolution.scene.rawValue)
                LabeledContent("confidence", value: confidenceText(result.sceneResolution.confidence))
                LabeledContent("manualSelection", value: manualSelectionMessage(for: result.sceneResolution.confidence))
            }
        }
    }

    private func metricSection(_ record: ImageRecognitionMetricRecord?) -> some View {
        debugCard {
            VStack(alignment: .leading, spacing: 10) {
                debugTitle("本地评估日志")

                if let record {
                    LabeledContent("predictedScene", value: record.predictedScene.rawValue)
                    LabeledContent("top3Scenes", value: record.top3Scenes.map(\.rawValue).joined(separator: ", "))
                    LabeledContent("userSelectedScene", value: record.userSelectedScene?.rawValue ?? "none")
                    LabeledContent("wasCorrectionNeeded", value: record.wasUserCorrectionNeeded ? "true" : "false")
                    LabeledContent("captionRating", value: record.captionRating.map(String.init) ?? "not rated")
                    LabeledContent("latency", value: "\(Int(record.modelLatencyMs.rounded()))ms")
                    LabeledContent("imageSize", value: record.imageSize)
                } else {
                    Text("暂无本地识别评估记录。选择照片、手动修正场景或给文案评分后会写入本机日志。")
                        .font(.caption)
                        .foregroundStyle(SnapCopyTheme.secondaryText)
                }
            }
        }
    }

    private func featureSection(_ flags: ImageFeatureFlags) -> some View {
        debugCard {
            VStack(alignment: .leading, spacing: 10) {
                debugTitle("检测到的产品特征")

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
                    featureRow("人", flags.hasPerson)
                    featureRow("食物", flags.hasFood)
                    featureRow("宠物", flags.hasPet)
                    featureRow("街景", flags.hasStreet)
                    featureRow("建筑", flags.hasBuilding)
                    featureRow("天空", flags.hasSky)
                    featureRow("植物", flags.hasPlant)
                }
            }
        }
    }

    private func semanticSection(_ summary: ImageSemanticSummary) -> some View {
        debugCard {
            VStack(alignment: .leading, spacing: 10) {
                debugTitle("本地语义增强 2.0")

                if !summary.hasUsefulContext {
                    Text("暂无语义组合结果")
                        .font(.caption)
                        .foregroundStyle(SnapCopyTheme.secondaryText)
                } else {
                    if let captionFocus = summary.captionFocus {
                        LabeledContent("captionFocus", value: captionFocus)
                    }

                    semanticRows("subjectCues", summary.subjectCues)
                    semanticRows("objectCues", summary.objectCues)
                    semanticRows("actionCues", summary.actionCues)
                    semanticRows("relationshipCues", summary.relationshipCues)
                    semanticRows("atmosphereCues", summary.atmosphereCues)
                    semanticRows("cautionRules", summary.cautionRules)
                }
            }
        }
    }

    private func labelsSection(_ labels: [VisionImageLabel]) -> some View {
        debugCard {
            VStack(alignment: .leading, spacing: 10) {
                debugTitle("Vision 原始标签")

                if labels.isEmpty {
                    Text("无标签")
                        .font(.caption)
                        .foregroundStyle(SnapCopyTheme.secondaryText)
                } else {
                    ForEach(labels, id: \.name) { label in
                        HStack {
                            Text(label.name)
                                .font(.caption.monospaced())
                                .foregroundStyle(SnapCopyTheme.primaryText)
                                .textSelection(.enabled)

                            Spacer()

                            Text(confidenceText(label.confidence))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(SnapCopyTheme.rose)
                        }
                    }
                }
            }
        }
    }

    private func ocrSection(_ texts: [RecognizedTextObservation]) -> some View {
        debugCard {
            VStack(alignment: .leading, spacing: 10) {
                debugTitle("OCR 识别文字")

                if texts.isEmpty {
                    Text("未识别到文字")
                        .font(.caption)
                        .foregroundStyle(SnapCopyTheme.secondaryText)
                } else {
                    ForEach(texts, id: \.text) { text in
                        HStack(alignment: .firstTextBaseline) {
                            Text(text.text)
                                .font(.caption)
                                .foregroundStyle(SnapCopyTheme.primaryText)
                                .textSelection(.enabled)

                            Spacer()

                            Text(confidenceText(text.confidence))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(SnapCopyTheme.rose)
                        }
                    }
                }
            }
        }
    }

    private func textSection(title: String, text: String) -> some View {
        debugCard {
            VStack(alignment: .leading, spacing: 10) {
                debugTitle(title)

                Text(text.isEmpty ? "尚未生成。" : text)
                    .font(.caption.monospaced())
                    .foregroundStyle(SnapCopyTheme.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
    }

    private var validationChecklist: some View {
        debugCard {
            VStack(alignment: .leading, spacing: 10) {
                debugTitle("13 类照片验证清单")

                Text("""
                早餐 / 咖啡 / 散步 / 街景 / 旅行 / 宠物 / 穿搭 / 健身 / 日落 / 室内生活 / 工作桌面 / 餐厅食物 / unknown

                每张都看四件事：
                1. 识别结果是否合理
                2. 推断场景是否合理
                3. prompt 是否包含具体场景
                4. 文案是否贴图
                """)
                .font(.caption)
                .foregroundStyle(SnapCopyTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func debugCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SnapCopyTheme.cardBackground, in: RoundedRectangle(cornerRadius: SnapCopyTheme.controlCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: SnapCopyTheme.controlCornerRadius, style: .continuous)
                    .stroke(SnapCopyTheme.hairline, lineWidth: 1)
            }
    }

    private func debugTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline.weight(.semibold))
            .foregroundStyle(SnapCopyTheme.primaryText)
    }

    private func semanticRows(_ title: String, _ values: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(SnapCopyTheme.secondaryText)

            Text(values.isEmpty ? "none" : values.joined(separator: "\n"))
                .font(.caption.monospaced())
                .foregroundStyle(SnapCopyTheme.primaryText)
                .textSelection(.enabled)
        }
    }

    private func featureRow(_ title: String, _ value: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: value ? "checkmark.circle.fill" : "minus.circle")
                .foregroundStyle(value ? SnapCopyTheme.sage : SnapCopyTheme.secondaryText)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(SnapCopyTheme.primaryText)
        }
    }

    private func confidenceText(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func manualSelectionMessage(for confidence: Double) -> String {
        if confidence >= 0.80 {
            return "直接使用本地识别结果"
        }

        if confidence >= 0.50 {
            return "建议显示 Top-3 候选，用户可选择场景"
        }

        return "低置信度，应提示用户手动选择或稍后使用云端增强识别"
    }
}
