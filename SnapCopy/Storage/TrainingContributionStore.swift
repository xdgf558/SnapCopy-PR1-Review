import Foundation

final class TrainingContributionStore {
    private let storageKey = "snapcopy.trainingContribution.records"
    private let maxRecords = 300
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func loadRecords() -> [TrainingContributionLocalRecord] {
        guard let data = userDefaults.data(forKey: storageKey),
              let records = try? decoder.decode([TrainingContributionLocalRecord].self, from: data) else {
            return []
        }

        return records.sorted { $0.createdAt > $1.createdAt }
    }

    func record(_ record: TrainingContributionLocalRecord) {
        var records = loadRecords()
        records.removeAll { $0.consentId == record.consentId }
        records.insert(record, at: 0)
        save(Array(records.prefix(maxRecords)))
    }

    func clear() {
        userDefaults.removeObject(forKey: storageKey)
    }

    private func save(_ records: [TrainingContributionLocalRecord]) {
        guard let data = try? encoder.encode(records) else {
            return
        }

        userDefaults.set(data, forKey: storageKey)
    }
}
