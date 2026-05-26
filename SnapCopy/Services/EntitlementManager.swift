import Combine
import Foundation

@MainActor
final class EntitlementManager: ObservableObject {
    @Published var level: EntitlementLevel {
        didSet {
            saveLevel()
        }
    }
    @Published private(set) var appAccountToken: UUID?

    private let defaults: UserDefaults
    private let storageKey: String

    init(defaults: UserDefaults = .standard, storageKey: String = "snapcopy.entitlementLevel") {
        self.defaults = defaults
        self.storageKey = storageKey

        #if DEBUG
        if let rawValue = defaults.string(forKey: storageKey),
           let savedLevel = EntitlementLevel(rawValue: rawValue) {
            level = savedLevel
        } else {
            level = .free
        }
        #else
        level = .free
        defaults.set(EntitlementLevel.free.rawValue, forKey: storageKey)
        #endif
    }

    var canUseMembershipMockControls: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    var canUseAdvancedStyles: Bool {
        level == .plus || level == .pro
    }

    var canUseCloudImageEnhancement: Bool {
        level == .pro
    }

    var canRemoveWatermark: Bool {
        level == .plus || level == .pro
    }

    func configureAppAccountToken(_ token: UUID) {
        appAccountToken = token
    }

    private func saveLevel() {
        #if DEBUG
        defaults.set(level.rawValue, forKey: storageKey)
        #else
        defaults.set(EntitlementLevel.free.rawValue, forKey: storageKey)
        #endif
    }
}
