import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var usageLimiter: UsageLimiter
    @EnvironmentObject private var appLanguageManager: AppLanguageManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "clock.badge.exclamationmark")
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundStyle(SnapCopyTheme.rose)
                            .frame(width: 64, height: 64)
                            .background(SnapCopyTheme.rose.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                        Text(uiLanguage.text(.paywallTitle))
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text(uiLanguage.text(.paywallSubtitle))
                            .font(.body)
                            .foregroundStyle(.secondary)

                        Text(paywallUsageText)
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundStyle(SnapCopyTheme.rose)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(SnapCopyTheme.rose.opacity(0.1), in: Capsule())
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text(uiLanguage.text(.paywallGotIt))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(SnapCopyTheme.rose)
                }
                .padding(24)
            }
            .navigationTitle(uiLanguage.text(.paywallNavigationTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }

    private var uiLanguage: AppLanguage {
        appLanguageManager.language
    }

    private var paywallUsageText: String {
        let freeLimit = EntitlementLevel.free.dailyCaptionGenerationLimit ?? 0

        switch uiLanguage {
        case .simplifiedChinese:
            return "\(uiLanguage.text(.paywallTodayCount)) \(usageLimiter.record.captionGenerations) / \(freeLimit) 次"
        case .english:
            return "\(uiLanguage.text(.paywallTodayCount)): \(usageLimiter.record.captionGenerations) / \(freeLimit)"
        case .japanese:
            return "\(uiLanguage.text(.paywallTodayCount))：\(usageLimiter.record.captionGenerations) / \(freeLimit) 回"
        case .traditionalChinese:
            return "\(uiLanguage.text(.paywallTodayCount)) \(usageLimiter.record.captionGenerations) / \(freeLimit) 次"
        }
    }
}
