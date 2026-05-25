import Foundation

final class TrainingContributionStore {
    private let storageKey = "snapcopy.trainingContribution.records"
    private let globalDecisionKey = "snapcopy.trainingContribution.globalDecision"
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

    func loadGlobalDecision() -> TrainingContributionDecision? {
        guard let rawValue = userDefaults.string(forKey: globalDecisionKey) else {
            return nil
        }

        return TrainingContributionDecision(rawValue: rawValue)
    }

    func saveGlobalDecision(_ decision: TrainingContributionDecision) {
        userDefaults.set(decision.rawValue, forKey: globalDecisionKey)
    }

    func clearGlobalDecision() {
        userDefaults.removeObject(forKey: globalDecisionKey)
    }

    func clear() {
        userDefaults.removeObject(forKey: storageKey)
        userDefaults.removeObject(forKey: globalDecisionKey)
    }

    private func save(_ records: [TrainingContributionLocalRecord]) {
        guard let data = try? encoder.encode(records) else {
            return
        }

        userDefaults.set(data, forKey: storageKey)
    }
}
