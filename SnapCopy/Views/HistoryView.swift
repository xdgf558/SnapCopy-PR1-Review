import SwiftUI
import UIKit

struct HistoryView: View {
    @EnvironmentObject private var appLanguageManager: AppLanguageManager

    @State private var items: [CaptionHistoryItem] = []
    @State private var selectedFilter: HistoryFilter = .all
    @State private var sharePayload: HistorySharePayload?
    @State private var confirmationMessage: String?
    @State private var confirmationID = UUID()

    private let historyStore = CaptionHistoryStore()

    var body: some View {
        ZStack {
            SnapCopyTheme.appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    Picker(uiLanguage.text(.historyAndFavorites), selection: $selectedFilter) {
                        ForEach(HistoryFilter.allCases) { filter in
                            Text(title(for: filter)).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)

                    if filteredItems.isEmpty {
                        HistoryEmptyState(text: selectedFilter == .favorites ? uiLanguage.text(.favoritesEmpty) : uiLanguage.text(.historyEmpty))
                            .padding(.top, 34)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredItems) { item in
                                HistoryItemCard(
                                    item: item,
                                    uiLanguage: uiLanguage,
                                    onCopy: { copy(item) },
                                    onShare: { share(item) },
                                    onToggleFavorite: { toggleFavorite(item) },
                                    onDelete: { delete(item) }
                                )
                            }
                        }
                    }
                }
                .frame(maxWidth: 560)
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(uiLanguage.text(.historyAndFavorites))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(item: $sharePayload) { payload in
            ShareSheet(activityItems: payload.activityItems, onComplete: nil)
        }
        .overlay(alignment: .bottom) {
            if let confirmationMessage {
                Text(confirmationMessage)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.78), in: Capsule())
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: confirmationMessage)
        .onAppear(perform: reload)
    }

    private var uiLanguage: AppLanguage {
        appLanguageManager.language
    }

    private var filteredItems: [CaptionHistoryItem] {
        switch selectedFilter {
        case .all:
            return items
        case .favorites:
            return items.filter(\.isFavorite)
        }
    }

    private func reload() {
        items = historyStore.loadItems()
    }

    private func copy(_ item: CaptionHistoryItem) {
        UIPasteboard.general.string = item.caption.text
        historyStore.recordInteraction(for: item.caption, image: item.thumbnailImage, interaction: .copied)
        reload()
        showTransientMessage(uiLanguage.text(.copied))
    }

    private func share(_ item: CaptionHistoryItem) {
        historyStore.recordInteraction(for: item.caption, image: item.thumbnailImage, interaction: .shared)
        reload()

        if let thumbnailImage = item.thumbnailImage {
            UIPasteboard.general.string = item.caption.text
            sharePayload = HistorySharePayload(activityItems: [item.caption.text, thumbnailImage])
        } else {
            sharePayload = HistorySharePayload(activityItems: [item.caption.text])
        }
    }

    private func toggleFavorite(_ item: CaptionHistoryItem) {
        let isNowFavorite = historyStore.toggleFavorite(itemID: item.id)
        reload()
        showTransientMessage(uiLanguage.text(isNowFavorite ? .savedToFavorites : .removedFromFavorites))
    }

    private func delete(_ item: CaptionHistoryItem) {
        withAnimation(.easeInOut(duration: 0.18)) {
            historyStore.deleteItem(item.id)
            reload()
        }
    }

    private func title(for filter: HistoryFilter) -> String {
        switch filter {
        case .all:
            return uiLanguage.text(.allHistory)
        case .favorites:
            return uiLanguage.text(.favorites)
        }
    }

    private func showTransientMessage(_ message: String) {
        let id = UUID()
        confirmationID = id
        confirmationMessage = message

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            if confirmationID == id {
                confirmationMessage = nil
            }
        }
    }
}

private enum HistoryFilter: String, CaseIterable, Identifiable {
    case all
    case favorites

    var id: String { rawValue }
}

private struct HistorySharePayload: Identifiable {
    let id = UUID()
    let activityItems: [Any]
}

private struct HistoryEmptyState: View {
    let text: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(SnapCopyTheme.rose)

            Text(text)
                .font(.body.weight(.medium))
                .foregroundStyle(SnapCopyTheme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(SnapCopyTheme.cardBackground, in: RoundedRectangle(cornerRadius: SnapCopyTheme.largeCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: SnapCopyTheme.largeCornerRadius, style: .continuous)
                .stroke(.white.opacity(0.58), lineWidth: 1)
        }
    }
}

private struct HistoryItemCard: View {
    let item: CaptionHistoryItem
    let uiLanguage: AppLanguage
    let onCopy: () -> Void
    let onShare: () -> Void
    let onToggleFavorite: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                thumbnail

                VStack(alignment: .leading, spacing: 8) {
                    Text(item.caption.text)
                        .font(.body.weight(.medium))
                        .foregroundStyle(SnapCopyTheme.primaryText)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(metadataText)
                        .font(.caption)
                        .foregroundStyle(SnapCopyTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 8) {
                Button(action: onCopy) {
                    Label(uiLanguage.text(.copy), systemImage: "doc.on.doc")
                }

                Button(action: onShare) {
                    Label(uiLanguage.text(.share), systemImage: "square.and.arrow.up")
                }

                Button(action: onToggleFavorite) {
                    Label(item.isFavorite ? uiLanguage.text(.favorited) : uiLanguage.text(.favorite), systemImage: item.isFavorite ? "star.fill" : "star")
                }
            }
            .buttonStyle(HistoryActionButtonStyle())

            Button(role: .destructive, action: onDelete) {
                Label(uiLanguage.text(.delete), systemImage: "trash")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SnapCopyTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: SnapCopyTheme.largeCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: SnapCopyTheme.largeCornerRadius, style: .continuous)
                .stroke(.white.opacity(0.62), lineWidth: 1)
        }
        .shadow(color: SnapCopyTheme.rose.opacity(0.08), radius: 16, y: 8)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = item.thumbnailImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 74, height: 74)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.74), lineWidth: 1)
                }
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(SnapCopyTheme.controlBackground)
                .frame(width: 74, height: 74)
                .overlay {
                    Image(systemName: "text.quote")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(SnapCopyTheme.rose)
                }
        }
    }

    private var metadataText: String {
        [
            uiLanguage.platformName(item.caption.platform),
            uiLanguage.lengthLevelName(item.caption.lengthLevel),
            item.lastUpdatedAt.formatted(date: .abbreviated, time: .shortened)
        ].joined(separator: " · ")
    }
}

private struct HistoryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .foregroundStyle(SnapCopyTheme.rose)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(SnapCopyTheme.controlBackground.opacity(configuration.isPressed ? 0.66 : 1), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(SnapCopyTheme.hairline, lineWidth: 1)
            }
    }
}

private extension CaptionHistoryItem {
    var thumbnailImage: UIImage? {
        guard let thumbnailData else {
            return nil
        }

        return UIImage(data: thumbnailData)
    }
}
