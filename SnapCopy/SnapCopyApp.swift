import SwiftUI

@main
struct SnapCopyApp: App {
    @StateObject private var userIdentityManager = UserIdentityManager()
    @StateObject private var entitlementManager = EntitlementManager()
    @StateObject private var usageLimiter = UsageLimiter()
    @StateObject private var appLanguageManager = AppLanguageManager()

    var body: some Scene {
        WindowGroup {
            StartupShellView()
                .environmentObject(userIdentityManager)
                .environmentObject(entitlementManager)
                .environmentObject(usageLimiter)
                .environmentObject(appLanguageManager)
                .environment(\.locale, Locale(identifier: appLanguageManager.language.localeIdentifier))
                .tint(SnapCopyTheme.rose)
                .preferredColorScheme(.light)
                .task {
                    entitlementManager.configureAppAccountToken(userIdentityManager.appUserId)
                }
        }
    }
}

private struct StartupShellView: View {
    @State private var isSplashVisible = true

    var body: some View {
        ZStack {
            HomeView()

            if isSplashVisible {
                StartupSplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 650_000_000)

            await MainActor.run {
                withAnimation(.easeOut(duration: 0.32)) {
                    isSplashVisible = false
                }
            }
        }
    }
}

private struct StartupSplashView: View {
    @EnvironmentObject private var appLanguageManager: AppLanguageManager

    var body: some View {
        ZStack {
            SnapCopyTheme.launchBackground
                .ignoresSafeArea()

            VStack(spacing: 22) {
                ZStack {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(SnapCopyTheme.primaryGradient)
                        .frame(width: 86, height: 86)
                        .shadow(color: SnapCopyTheme.rose.opacity(0.20), radius: 20, y: 10)

                    Image(systemName: "sparkles")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(spacing: 8) {
                    Text("SnapCopy")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(SnapCopyTheme.primaryText)

                    Text(appLanguageManager.language.text(.appSubtitle))
                        .font(.title3.weight(.medium))
                        .foregroundStyle(SnapCopyTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
            .offset(y: -24)
        }
        .accessibilityHidden(true)
    }
}

enum SnapCopyTheme {
    static let rose = Color(red: 0.72, green: 0.25, blue: 0.38)
    static let coral = Color(red: 0.92, green: 0.47, blue: 0.43)
    static let plum = Color(red: 0.30, green: 0.22, blue: 0.34)
    static let sage = Color(red: 0.46, green: 0.59, blue: 0.53)
    static let champagne = Color(red: 0.95, green: 0.78, blue: 0.56)
    static let petal = Color(red: 1.00, green: 0.86, blue: 0.89)
    static let mintMist = Color(red: 0.88, green: 0.96, blue: 0.92)
    static let primaryText = Color(red: 0.18, green: 0.14, blue: 0.20)
    static let secondaryText = Color(red: 0.42, green: 0.37, blue: 0.42)

    static let appBackground = LinearGradient(
        colors: [
            Color(red: 1.00, green: 0.96, blue: 0.94),
            Color(red: 0.99, green: 0.91, blue: 0.93),
            Color(red: 0.95, green: 0.98, blue: 0.95)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let launchBackground = LinearGradient(
        colors: [
            Color(red: 1.00, green: 0.96, blue: 0.94),
            Color(red: 0.99, green: 0.91, blue: 0.93)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let primaryGradient = LinearGradient(
        colors: [rose, coral],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let softPanelGradient = LinearGradient(
        colors: [
            Color(red: 1.00, green: 0.93, blue: 0.91),
            Color(red: 0.96, green: 0.96, blue: 0.89),
            Color(red: 0.90, green: 0.96, blue: 0.93)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static var cardBackground: Color {
        Color(red: 1.00, green: 0.98, blue: 0.97).opacity(0.70)
    }

    static var controlBackground: Color {
        Color.white.opacity(0.58)
    }

    static var elevatedSurface: Color {
        Color(red: 1.00, green: 0.99, blue: 0.98).opacity(0.82)
    }

    static var hairline: Color {
        Color(red: 0.78, green: 0.53, blue: 0.58).opacity(0.22)
    }

    static var glassHighlight: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.72),
                Color.white.opacity(0.18),
                petal.opacity(0.18)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static let largeCornerRadius: CGFloat = 34
    static let controlCornerRadius: CGFloat = 26
}
