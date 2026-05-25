import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var entitlementManager: EntitlementManager
    @EnvironmentObject private var usageLimiter: UsageLimiter
    @EnvironmentObject private var appLanguageManager: AppLanguageManager

    @State private var localAIStatus = LocalAIAvailabilityDetector.currentStatus()
    @State private var selectedCaptionLanguage: CaptionLanguage = .simplifiedChinese
    @State private var selectedInterfaceLanguage: AppLanguage = .simplifiedChinese
    @State private var feedbackConfirmationMessage: String?
    @State private var recognitionLogConfirmationMessage: String?
    @State private var recognitionLogSharePayload: SettingsSharePayload?
    @State private var contributionDecision: TrainingContributionDecision?

    private let preferenceStore = UserPreferenceStore()
    private let recognitionMetricsLogger = ImageRecognitionMetricsLogger()
    private let trainingContributionStore = TrainingContributionStore()
    private let feedbackEmail = "yehao1105@gmail.com"

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(uiLanguage.text(.preferenceTitle))
                        .font(.headline)

                    Text(uiLanguage.text(.preferenceSubtitle))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section(uiLanguage.text(.interfaceLanguage)) {
                Picker(uiLanguage.text(.interfaceLanguagePicker), selection: $selectedInterfaceLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }

                Text(uiLanguage.text(.interfaceLanguageNote))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(uiLanguage.text(.captionLanguage)) {
                Picker(uiLanguage.text(.generationLanguage), selection: $selectedCaptionLanguage) {
                    ForEach(CaptionLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }

                Text(uiLanguage.text(.captionLanguageNote))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(uiLanguage.text(.todayUsage)) {
                LabeledContent(uiLanguage.text(.captionGeneration), value: captionUsageValue)
                LabeledContent(uiLanguage.text(.basicEnhancement), value: uiLanguage.text(.unlimited))

                Text(uiLanguage.text(.betaUsageNote))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(uiLanguage.text(.membershipMock)) {
                Picker(uiLanguage.text(.currentLevel), selection: $entitlementManager.level) {
                    ForEach(EntitlementLevel.allCases) { level in
                        Text(level.displayName).tag(level)
                    }
                }

                Text(uiLanguage.entitlementDescription(entitlementManager.level))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(uiLanguage.text(.localAI)) {
                LabeledContent("Foundation Models", value: localizedLocalAIStatus.title)

                Text(localizedLocalAIStatus.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(uiLanguage.text(.proCloudFrameworkTitle)) {
                LabeledContent(uiLanguage.text(.cloudEnhance), value: entitlementManager.canUseCloudImageEnhancement ? uiLanguage.text(.laterStage) : uiLanguage.text(.unavailable))

                Text(uiLanguage.text(.proCloudFrameworkReady))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(uiLanguage.text(.betaTestGuide)) {
                Text(uiLanguage.text(.betaTestGuideText))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section(localizedContributionSettingsTitle) {
                LabeledContent(localizedContributionDecisionTitle, value: localizedContributionDecisionValue)

                Text(localizedContributionSettingsNote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    resetContributionDecision()
                } label: {
                    Label(localizedContributionResetTitle, systemImage: "arrow.counterclockwise")
                }
                .disabled(contributionDecision == nil)
            }

            Section(uiLanguage.text(.feedback)) {
                Text(uiLanguage.text(.feedbackIntro))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    copyFeedbackEmail()
                } label: {
                    Label(uiLanguage.text(.copyFeedbackEmail), systemImage: "envelope")
                }

                if let feedbackConfirmationMessage {
                    Text(feedbackConfirmationMessage)
                        .font(.footnote)
                        .foregroundStyle(SnapCopyTheme.sage)
                }
            }

            if isDeveloperDiagnosticsEnabled {
                Section("开发者诊断") {
                    LabeledContent("识别日志", value: "\(recognitionLogCount) 条")

                    Button {
                        copyRecognitionLog()
                    } label: {
                        Label("复制识别日志 JSON", systemImage: "doc.on.doc")
                    }
                    .disabled(recognitionLogCount == 0)

                    Button {
                        shareRecognitionLog()
                    } label: {
                        Label("分享识别日志文件", systemImage: "square.and.arrow.up")
                    }
                    .disabled(recognitionLogCount == 0)

                    Text("仅导出预测场景、top 3、手动修正、评分、耗时、图片尺寸和时间，不包含照片原图。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if let recognitionLogConfirmationMessage {
                        Text(recognitionLogConfirmationMessage)
                            .font(.footnote)
                            .foregroundStyle(SnapCopyTheme.sage)
                    }
                }
            }

            Section(uiLanguage.text(.aboutSnapCopy)) {
                LabeledContent(uiLanguage.text(.version), value: appVersionText)

                VStack(alignment: .leading, spacing: 6) {
                    Text(uiLanguage.text(.updateNotes))
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(updateNotes)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 2)

                LabeledContent(uiLanguage.text(.developer), value: "Station Cat")
            }
        }
        .navigationTitle(uiLanguage.text(.settings))
        .scrollContentBackground(.hidden)
        .background(SnapCopyTheme.appBackground)
        .sheet(item: $recognitionLogSharePayload) { payload in
            ShareSheet(activityItems: payload.activityItems, onComplete: nil)
        }
        .onAppear {
            usageLimiter.refreshIfNeeded()
            localAIStatus = LocalAIAvailabilityDetector.currentStatus()
            selectedCaptionLanguage = preferenceStore.load().preferredCaptionLanguage
            selectedInterfaceLanguage = appLanguageManager.language
            contributionDecision = trainingContributionStore.loadGlobalDecision()
        }
        .onChange(of: selectedInterfaceLanguage) { language in
            feedbackConfirmationMessage = nil
            appLanguageManager.update(language)
        }
        .onChange(of: selectedCaptionLanguage) { language in
            preferenceStore.updatePreferredCaptionLanguage(language)
        }
    }

    private var uiLanguage: AppLanguage {
        appLanguageManager.language
    }

    private var captionUsageValue: String {
        let used = usageLimiter.record.captionGenerations
        return uiLanguage.usageValue(used: used, limit: entitlementManager.level.dailyCaptionGenerationLimit)
    }

    private var localizedLocalAIStatus: (title: String, detail: String) {
        uiLanguage.localAIStatusText(localAIStatus)
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "v\(version) (\(build))"
    }

    private var updateNotes: String {
        uiLanguage.developmentNotesText()
    }

    private var isDeveloperDiagnosticsEnabled: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    private var recognitionLogCount: Int {
        recognitionMetricsLogger.loadRecords().count
    }

    private func copyFeedbackEmail() {
        UIPasteboard.general.string = feedbackEmail
        feedbackConfirmationMessage = uiLanguage.text(.feedbackEmailCopied)
    }

    private func copyRecognitionLog() {
        guard let data = recognitionMetricsLogger.makeExportData(appVersion: appVersionText),
              let json = String(data: data, encoding: .utf8) else {
            recognitionLogConfirmationMessage = "识别日志导出失败。"
            return
        }

        UIPasteboard.general.string = json
        recognitionLogConfirmationMessage = "识别日志 JSON 已复制。"
    }

    private func shareRecognitionLog() {
        guard let data = recognitionMetricsLogger.makeExportData(appVersion: appVersionText) else {
            recognitionLogConfirmationMessage = "识别日志导出失败。"
            return
        }

        do {
            let fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("snapcopy-recognition-log-\(Int(Date().timeIntervalSince1970)).json")
            try data.write(to: fileURL, options: .atomic)
            recognitionLogSharePayload = SettingsSharePayload(activityItems: [fileURL])
            recognitionLogConfirmationMessage = "识别日志文件已准备好。"
        } catch {
            recognitionLogConfirmationMessage = "识别日志文件创建失败。"
        }
    }

    private func resetContributionDecision() {
        trainingContributionStore.clearGlobalDecision()
        contributionDecision = nil
    }

    private var localizedContributionSettingsTitle: String {
        switch uiLanguage {
        case .simplifiedChinese:
            "匿名贡献"
        case .english:
            "Anonymous contribution"
        case .japanese:
            "匿名提供"
        case .traditionalChinese:
            "匿名貢獻"
        }
    }

    private var localizedContributionDecisionTitle: String {
        switch uiLanguage {
        case .simplifiedChinese:
            "当前选择"
        case .english:
            "Current choice"
        case .japanese:
            "現在の選択"
        case .traditionalChinese:
            "目前選擇"
        }
    }

    private var localizedContributionDecisionValue: String {
        switch (uiLanguage, contributionDecision) {
        case (_, nil):
            switch uiLanguage {
            case .simplifiedChinese:
                return "下次询问"
            case .english:
                return "Ask next time"
            case .japanese:
                return "次回確認"
            case .traditionalChinese:
                return "下次詢問"
            }
        case (.simplifiedChinese, .granted):
            return "默认贡献"
        case (.english, .granted):
            return "Contribute by default"
        case (.japanese, .granted):
            return "既定で提供"
        case (.traditionalChinese, .granted):
            return "預設貢獻"
        case (.simplifiedChinese, .declined):
            return "默认不贡献"
        case (.english, .declined):
            return "Do not contribute by default"
        case (.japanese, .declined):
            return "既定で提供しない"
        case (.traditionalChinese, .declined):
            return "預設不貢獻"
        }
    }

    private var localizedContributionSettingsNote: String {
        switch uiLanguage {
        case .simplifiedChinese:
            "首次选择后，App 会按该选择自动处理后续照片 metadata 和最终文案样本。当前版本不上传原图。"
        case .english:
            "After your first choice, the app will automatically apply it to future photo metadata and final caption samples. This build does not upload original photos."
        case .japanese:
            "初回選択後、写真メタデータと最終文案サンプルには同じ選択を自動適用します。このバージョンでは元画像をアップロードしません。"
        case .traditionalChinese:
            "首次選擇後，App 會按該選擇自動處理後續照片 metadata 和最終文案樣本。目前版本不會上傳原圖。"
        }
    }

    private var localizedContributionResetTitle: String {
        switch uiLanguage {
        case .simplifiedChinese:
            "重置选择"
        case .english:
            "Reset choice"
        case .japanese:
            "選択をリセット"
        case .traditionalChinese:
            "重置選擇"
        }
    }
}

private struct SettingsSharePayload: Identifiable {
    let id = UUID()
    let activityItems: [Any]
}
