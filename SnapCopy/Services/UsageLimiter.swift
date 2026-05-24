import Combine
import Foundation

@MainActor
final class UsageLimiter: ObservableObject {
    @Published private(set) var record: UsageRecord

    private let defaults: UserDefaults
    private let storageKey: String
    private let calendar: Calendar

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "snapcopy.usageRecord",
        calendar: Calendar = .current,
        now: Date = Date()
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.calendar = calendar

        let currentDay = Self.dayIdentifier(for: now, calendar: calendar)
        if let data = defaults.data(forKey: storageKey),
           let savedRecord = try? JSONDecoder().decode(UsageRecord.self, from: data),
           savedRecord.dayIdentifier == currentDay {
            record = savedRecord
        } else {
            record = .empty(dayIdentifier: currentDay)
        }
    }

    func refreshIfNeeded(now: Date = Date()) {
        let currentDay = Self.dayIdentifier(for: now, calendar: calendar)
        guard record.dayIdentifier != currentDay else {
            return
        }

        record = .empty(dayIdentifier: currentDay)
        saveRecord()
    }

    func canGenerateCaption(for level: EntitlementLevel, now: Date = Date()) -> Bool {
        refreshIfNeeded(now: now)

        guard let limit = level.dailyCaptionGenerationLimit else {
            return true
        }

        return record.captionGenerations < limit
    }

    func recordCaptionGeneration(for level: EntitlementLevel, now: Date = Date()) {
        refreshIfNeeded(now: now)

        if let limit = level.dailyCaptionGenerationLimit {
            record.captionGenerations = min(record.captionGenerations + 1, limit)
        } else {
            record.captionGenerations += 1
        }

        saveRecord()
    }

    func canUseBasicImageEnhancement(for level: EntitlementLevel, now: Date = Date()) -> Bool {
        refreshIfNeeded(now: now)

        guard let limit = level.dailyBasicImageEnhancementLimit else {
            return true
        }

        return record.basicImageEnhancements < limit
    }

    func recordBasicImageEnhancement(for level: EntitlementLevel, now: Date = Date()) {
        refreshIfNeeded(now: now)

        if let limit = level.dailyBasicImageEnhancementLimit {
            record.basicImageEnhancements = min(record.basicImageEnhancements + 1, limit)
        } else {
            record.basicImageEnhancements += 1
        }

        saveRecord()
    }

    func canUseCloudEnhancement(for level: EntitlementLevel, isTestUser: Bool = false, now: Date = Date()) -> Bool {
        refreshIfNeeded(now: now)

        let limit = level.dailyCloudEnhancementLimit(isTestUser: isTestUser)
        return record.cloudEnhancements < limit
    }

    func recordCloudEnhancement(for level: EntitlementLevel, isTestUser: Bool = false, now: Date = Date()) {
        refreshIfNeeded(now: now)

        let limit = level.dailyCloudEnhancementLimit(isTestUser: isTestUser)
        record.cloudEnhancements = min(record.cloudEnhancements + 1, limit)
        saveRecord()
    }

    func remainingCloudEnhancements(for level: EntitlementLevel, isTestUser: Bool = false, now: Date = Date()) -> Int {
        refreshIfNeeded(now: now)

        let limit = level.dailyCloudEnhancementLimit(isTestUser: isTestUser)
        return max(0, limit - record.cloudEnhancements)
    }

    func captionGenerationsUsed(now: Date = Date()) -> Int {
        refreshIfNeeded(now: now)
        return record.captionGenerations
    }

    func remainingCaptionGenerations(for level: EntitlementLevel, now: Date = Date()) -> Int? {
        refreshIfNeeded(now: now)

        guard let limit = level.dailyCaptionGenerationLimit else {
            return nil
        }

        return max(0, limit - record.captionGenerations)
    }

    func resetToday(now: Date = Date()) {
        record = .empty(dayIdentifier: Self.dayIdentifier(for: now, calendar: calendar))
        saveRecord()
    }

    private func saveRecord() {
        guard let data = try? JSONEncoder().encode(record) else {
            return
        }

        defaults.set(data, forKey: storageKey)
    }

    private static func dayIdentifier(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }
}
