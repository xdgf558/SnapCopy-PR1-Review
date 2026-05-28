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
    @State private var selectedShareCardTemplate: ShareCardTemplate = ShareCardTemplateRepository().fallbackTemplate()
    @State private var selectedHistoryAutoDeleteDays = 3
    @State private var isClearHistoryConfirmationPresented = false
    @State private var historyCleanupConfirmationMessage: String?

    private let preferenceStore = UserPreferenceStore()
    private let recognitionMetricsLogger = ImageRecognitionMetricsLogger()
    private let trainingContributionStore = TrainingContributionStore()
    private let shareCardTemplateStore = ShareCardTemplateStore()
    private let shareCardTemplateRepository = ShareCardTemplateRepository()
    private let historyStore = CaptionHistoryStore()
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

            if entitlementManager.canUseMembershipMockControls {
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

            Section(localizedShareCardTemplateTitle) {
                Picker(localizedShareCardTemplatePickerTitle, selection: $selectedShareCardTemplate) {
                    ForEach(shareCardTemplateRepository.templates) { template in
                        Text(template.displayName(language: uiLanguage)).tag(template)
                    }
                }

                Text(selectedShareCardTemplate.description(language: uiLanguage))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(localizedShareCardTemplateNote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section(localizedHistorySettingsTitle) {
                Picker(localizedHistoryAutoDeleteTitle, selection: $selectedHistoryAutoDeleteDays) {
                    ForEach(CaptionHistoryStore.validAutoDeleteDays, id: \.self) { days in
                        Text(localizedHistoryAutoDeleteOption(days: days)).tag(days)
                    }
                }
                .pickerStyle(.segmented)

                Text(localizedHistoryAutoDeleteNote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(role: .destructive) {
                    isClearHistoryConfirmationPresented = true
                } label: {
                    Label(localizedClearHistoryTitle, systemImage: "trash")
                }

                if let historyCleanupConfirmationMessage {
                    Text(historyCleanupConfirmationMessage)
                        .font(.footnote)
                        .foregroundStyle(SnapCopyTheme.sage)
                }
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
        .confirmationDialog(
            localizedClearHistoryTitle,
            isPresented: $isClearHistoryConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(localizedClearHistoryConfirmTitle, role: .destructive) {
                clearHistoryItems()
            }

            Button(uiLanguage.text(.cancel), role: .cancel) {}
        } message: {
            Text(localizedClearHistoryConfirmationMessage)
        }
        .onAppear {
            usageLimiter.refreshIfNeeded()
            localAIStatus = LocalAIAvailabilityDetector.currentStatus()
            selectedCaptionLanguage = preferenceStore.load().preferredCaptionLanguage
            selectedInterfaceLanguage = appLanguageManager.language
            contributionDecision = trainingContributionStore.loadGlobalDecision()
            selectedShareCardTemplate = shareCardTemplateStore.load()
            selectedHistoryAutoDeleteDays = historyStore.autoDeleteDays()
            _ = historyStore.pruneExpiredHistory()
        }
        .onChange(of: selectedInterfaceLanguage) { language in
            feedbackConfirmationMessage = nil
            appLanguageManager.update(language)
        }
        .onChange(of: selectedCaptionLanguage) { language in
            preferenceStore.updatePreferredCaptionLanguage(language)
        }
        .onChange(of: selectedShareCardTemplate) { template in
            shareCardTemplateStore.save(template)
        }
        .onChange(of: selectedHistoryAutoDeleteDays) { days in
            historyStore.updateAutoDeleteDays(days)
            historyCleanupConfirmationMessage = localizedHistoryAutoDeleteUpdatedMessage(days: days)
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

    private func clearHistoryItems() {
        let deletedCount = historyStore.deleteHistoryItems(keepFavorites: true)
        historyCleanupConfirmationMessage = localizedHistoryClearedMessage(deletedCount: deletedCount)
    }

    private var localizedShareCardTemplateTitle: String {
        switch uiLanguage {
        case .simplifiedChinese:
            "分享卡片样式"
        case .english:
            "Share card style"
        case .japanese:
            "共有カードスタイル"
        case .traditionalChinese:
            "分享卡片樣式"
        }
    }

    private var localizedShareCardTemplatePickerTitle: String {
        switch uiLanguage {
        case .simplifiedChinese:
            "当前样式"
        case .english:
            "Current style"
        case .japanese:
            "現在のスタイル"
        case .traditionalChinese:
            "目前樣式"
        }
    }

    private var localizedShareCardTemplateNote: String {
        switch uiLanguage {
        case .simplifiedChinese:
            "分享时会把照片和文案整理成一张完整卡片，并自动加入 SnapCopy 品牌标识。"
        case .english:
            "When you share, SnapCopy turns the photo and caption into a polished card with the SnapCopy mark."
        case .japanese:
            "共有時に、写真と文案を SnapCopy のブランドマーク入りカードとして整えます。"
        case .traditionalChinese:
            "分享時會把照片和文案整理成一張完整卡片，並自動加入 SnapCopy 品牌標識。"
        }
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

    private var localizedHistorySettingsTitle: String {
        switch uiLanguage {
        case .simplifiedChinese:
            "历史记录"
        case .english:
            "History"
        case .japanese:
            "履歴"
        case .traditionalChinese:
            "歷史記錄"
        }
    }

    private var localizedHistoryAutoDeleteTitle: String {
        switch uiLanguage {
        case .simplifiedChinese:
            "自动删除"
        case .english:
            "Auto delete"
        case .japanese:
            "自動削除"
        case .traditionalChinese:
            "自動刪除"
        }
    }

    private func localizedHistoryAutoDeleteOption(days: Int) -> String {
        switch uiLanguage {
        case .simplifiedChinese:
            "\(days)天"
        case .english:
            "\(days)d"
        case .japanese:
            "\(days)日"
        case .traditionalChinese:
            "\(days)天"
        }
    }

    private var localizedHistoryAutoDeleteNote: String {
        switch uiLanguage {
        case .simplifiedChinese:
            "未收藏的历史记录会在超过所选天数后自动删除；收藏内容会保留。"
        case .english:
            "Unfavorited history is removed after the selected number of days. Favorites are kept."
        case .japanese:
            "お気に入り以外の履歴は選択した日数を過ぎると自動削除されます。お気に入りは残ります。"
        case .traditionalChinese:
            "未收藏的歷史記錄會在超過所選天數後自動刪除；收藏內容會保留。"
        }
    }

    private var localizedClearHistoryTitle: String {
        switch uiLanguage {
        case .simplifiedChinese:
            "清空未收藏历史"
        case .english:
            "Clear unfavorited history"
        case .japanese:
            "未收藏の履歴を消去"
        case .traditionalChinese:
            "清空未收藏歷史"
        }
    }

    private var localizedClearHistoryConfirmTitle: String {
        switch uiLanguage {
        case .simplifiedChinese:
            "确认清空"
        case .english:
            "Clear"
        case .japanese:
            "消去"
        case .traditionalChinese:
            "確認清空"
        }
    }

    private var localizedClearHistoryConfirmationMessage: String {
        switch uiLanguage {
        case .simplifiedChinese:
            "这会删除所有未收藏的历史记录，收藏内容会保留。"
        case .english:
            "This removes all unfavorited history. Favorites will be kept."
        case .japanese:
            "お気に入り以外の履歴をすべて削除します。お気に入りは残ります。"
        case .traditionalChinese:
            "這會刪除所有未收藏的歷史記錄，收藏內容會保留。"
        }
    }

    private func localizedHistoryClearedMessage(deletedCount: Int) -> String {
        switch uiLanguage {
        case .simplifiedChinese:
            return deletedCount > 0 ? "已删除 \(deletedCount) 条未收藏历史。" : "没有可删除的未收藏历史。"
        case .english:
            return deletedCount > 0 ? "Deleted \(deletedCount) unfavorited history items." : "No unfavorited history to delete."
        case .japanese:
            return deletedCount > 0 ? "未收藏の履歴を \(deletedCount) 件削除しました。" : "削除できる未收藏の履歴はありません。"
        case .traditionalChinese:
            return deletedCount > 0 ? "已刪除 \(deletedCount) 條未收藏歷史。" : "沒有可刪除的未收藏歷史。"
        }
    }

    private func localizedHistoryAutoDeleteUpdatedMessage(days: Int) -> String {
        switch uiLanguage {
        case .simplifiedChinese:
            return "历史记录会保留最近 \(days) 天，收藏内容不受影响。"
        case .english:
            return "History keeps the latest \(days) days. Favorites are not affected."
        case .japanese:
            return "履歴は直近 \(days) 日分を保持します。お気に入りは影響を受けません。"
        case .traditionalChinese:
            return "歷史記錄會保留最近 \(days) 天，收藏內容不受影響。"
        }
    }
}

private struct SettingsSharePayload: Identifiable {
    let id = UUID()
    let activityItems: [Any]
}
