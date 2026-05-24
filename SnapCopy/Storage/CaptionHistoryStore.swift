import Foundation
import UIKit

final class CaptionHistoryStore {
    private let storageKey = "snapcopy.captionHistoryItems"
    private let maxNonFavoriteItems = 120
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func loadItems() -> [CaptionHistoryItem] {
        guard let data = userDefaults.data(forKey: storageKey),
              let items = try? decoder.decode([CaptionHistoryItem].self, from: data) else {
            return []
        }

        return sorted(items)
    }

    func saveGeneratedCandidates(_ candidates: [CaptionCandidate], image: UIImage?) {
        guard !candidates.isEmpty else {
            return
        }

        var items = loadItems()
        let thumbnailData = makeThumbnailData(from: image)
        let now = Date()

        for candidate in candidates {
            upsert(
                candidate,
                in: &items,
                thumbnailData: thumbnailData,
                interaction: .generated,
                isFavoriteOverride: nil,
                date: now
            )
        }

        save(items)
    }

    func recordInteraction(
        for caption: CaptionCandidate,
        image: UIImage?,
        interaction: CaptionHistoryInteraction
    ) {
        var items = loadItems()
        upsert(
            caption,
            in: &items,
            thumbnailData: makeThumbnailData(from: image),
            interaction: interaction,
            isFavoriteOverride: nil,
            date: Date()
        )
        save(items)
    }

    @discardableResult
    func toggleFavorite(for caption: CaptionCandidate, image: UIImage?) -> Bool {
        var items = loadItems()
        let key = Self.key(for: caption.text)
        let now = Date()
        let thumbnailData = makeThumbnailData(from: image)
        let isNowFavorite: Bool

        if let index = items.firstIndex(where: { Self.key(for: $0.caption.text) == key }) {
            items[index].isFavorite.toggle()
            items[index].lastUpdatedAt = now
            items[index].lastInteraction = .favorited
            items[index].caption = caption
            if items[index].thumbnailData == nil {
                items[index].thumbnailData = thumbnailData
            }
            isNowFavorite = items[index].isFavorite
        } else {
            items.append(
                CaptionHistoryItem(
                    caption: caption,
                    createdAt: now,
                    lastUpdatedAt: now,
                    isFavorite: true,
                    lastInteraction: .favorited,
                    thumbnailData: thumbnailData
                )
            )
            isNowFavorite = true
        }

        save(items)
        return isNowFavorite
    }

    @discardableResult
    func toggleFavorite(itemID: UUID) -> Bool {
        var items = loadItems()
        guard let index = items.firstIndex(where: { $0.id == itemID }) else {
            return false
        }

        items[index].isFavorite.toggle()
        items[index].lastUpdatedAt = Date()
        items[index].lastInteraction = .favorited
        let isNowFavorite = items[index].isFavorite
        save(items)
        return isNowFavorite
    }

    func deleteItem(_ itemID: UUID) {
        var items = loadItems()
        items.removeAll { $0.id == itemID }
        save(items)
    }

    func favoriteCaptionKeys() -> Set<String> {
        Set(loadItems().filter(\.isFavorite).map { Self.key(for: $0.caption.text) })
    }

    static func key(for text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .filter { !$0.isWhitespace }
    }

    private func upsert(
        _ caption: CaptionCandidate,
        in items: inout [CaptionHistoryItem],
        thumbnailData: Data?,
        interaction: CaptionHistoryInteraction,
        isFavoriteOverride: Bool?,
        date: Date
    ) {
        let key = Self.key(for: caption.text)

        if let index = items.firstIndex(where: { Self.key(for: $0.caption.text) == key }) {
            let existingFavorite = items[index].isFavorite
            items[index].caption = caption
            items[index].lastUpdatedAt = date
            items[index].lastInteraction = interaction
            items[index].isFavorite = isFavoriteOverride ?? existingFavorite
            if let thumbnailData {
                items[index].thumbnailData = thumbnailData
            }
            return
        }

        items.append(
            CaptionHistoryItem(
                caption: caption,
                createdAt: date,
                lastUpdatedAt: date,
                isFavorite: isFavoriteOverride ?? false,
                lastInteraction: interaction,
                thumbnailData: thumbnailData
            )
        )
    }

    private func save(_ items: [CaptionHistoryItem]) {
        let favorites = items.filter(\.isFavorite)
        let nonFavorites = items
            .filter { !$0.isFavorite }
            .sorted { $0.lastUpdatedAt > $1.lastUpdatedAt }
            .prefix(maxNonFavoriteItems)
        let trimmedItems = sorted(favorites + nonFavorites)

        guard let data = try? encoder.encode(trimmedItems) else {
            return
        }

        userDefaults.set(data, forKey: storageKey)
    }

    private func sorted(_ items: [CaptionHistoryItem]) -> [CaptionHistoryItem] {
        items.sorted {
            if $0.lastUpdatedAt == $1.lastUpdatedAt {
                return $0.createdAt > $1.createdAt
            }

            return $0.lastUpdatedAt > $1.lastUpdatedAt
        }
    }

    private func makeThumbnailData(from image: UIImage?) -> Data? {
        guard let image else {
            return nil
        }

        let longestSide: CGFloat = 420
        let scale = min(longestSide / max(image.size.width, image.size.height), 1)
        let thumbnailSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: thumbnailSize)
        let thumbnail = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: thumbnailSize))
        }

        return thumbnail.jpegData(compressionQuality: 0.72)
    }
}
