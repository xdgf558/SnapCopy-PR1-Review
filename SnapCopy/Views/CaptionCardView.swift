import SwiftUI

struct CaptionCardView: View {
    @EnvironmentObject private var appLanguageManager: AppLanguageManager

    @Binding var candidate: CaptionCandidate
    let isFavorite: Bool
    let onCopy: (CaptionCandidate) -> Void
    let onShare: (CaptionCandidate) -> Void
    let onToggleFavorite: (CaptionCandidate) -> Void
    let onDislike: (CaptionCandidate) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(candidate.text)
                .font(.body.weight(.medium))
                .foregroundStyle(SnapCopyTheme.primaryText)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text(uiLanguage.styleName(candidate.style))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(styleColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(styleColor.opacity(0.12))
                    .clipShape(Capsule())

                Spacer()
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    actionButtons
                }

                VStack(alignment: .leading, spacing: 10) {
                    actionButtons
                }
            }
            .buttonStyle(CaptionActionButtonStyle())

            Button {
                onDislike(candidate)
            } label: {
                Label(uiLanguage.text(.dislikeNext), systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(CaptionDislikeButtonStyle())
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SnapCopyTheme.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: SnapCopyTheme.largeCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: SnapCopyTheme.largeCornerRadius, style: .continuous)
                .stroke(.white.opacity(0.62), lineWidth: 1)
        }
        .shadow(color: SnapCopyTheme.rose.opacity(0.09), radius: 18, y: 10)
    }

    @ViewBuilder
    private var actionButtons: some View {
        Button {
            onCopy(candidate)
        } label: {
            Label(uiLanguage.text(.copy), systemImage: "doc.on.doc")
        }

        Button {
            onShare(candidate)
        } label: {
            Label(uiLanguage.text(.share), systemImage: "square.and.arrow.up")
        }

        Button {
            onToggleFavorite(candidate)
        } label: {
            Label(isFavorite ? uiLanguage.text(.favorited) : uiLanguage.text(.favorite), systemImage: isFavorite ? "star.fill" : "star")
        }
    }

    private var uiLanguage: AppLanguage {
        appLanguageManager.language
    }

    private var styleColor: Color {
        switch candidate.style {
        case .healing:
            SnapCopyTheme.sage
        case .humor:
            Color(red: 0.70, green: 0.47, blue: 0.16)
        case .premium:
            SnapCopyTheme.plum
        case .xiaohongshu:
            SnapCopyTheme.rose
        case .concise:
            Color(red: 0.36, green: 0.50, blue: 0.70)
        case .poetic:
            Color(red: 0.48, green: 0.42, blue: 0.68)
        case .daily:
            Color(red: 0.35, green: 0.57, blue: 0.58)
        }
    }
}

private struct CaptionActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(SnapCopyTheme.rose)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(SnapCopyTheme.controlBackground.opacity(configuration.isPressed ? 0.66 : 1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(SnapCopyTheme.hairline, lineWidth: 1)
            }
    }
}

private struct CaptionDislikeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 11)
            .padding(.horizontal, 12)
            .foregroundStyle(SnapCopyTheme.secondaryText)
            .background(SnapCopyTheme.controlBackground.opacity(configuration.isPressed ? 0.54 : 0.86), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(SnapCopyTheme.hairline, lineWidth: 1)
            }
    }
}
