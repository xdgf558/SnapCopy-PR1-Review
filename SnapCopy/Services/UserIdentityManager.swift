import Combine
import Foundation
import Security

protocol UserIdentityStoring {
    func loadAppUserId() -> UUID?
    func saveAppUserId(_ id: UUID)
}

@MainActor
final class UserIdentityManager: ObservableObject {
    @Published private(set) var appUserId: UUID

    private let store: UserIdentityStoring

    init(store: UserIdentityStoring = KeychainUserIdentityStore()) {
        self.store = store

        if let existingId = store.loadAppUserId() {
            appUserId = existingId
        } else {
            let newId = UUID()
            store.saveAppUserId(newId)
            appUserId = newId
        }
    }
}

struct KeychainUserIdentityStore: UserIdentityStoring {
    private let service = "com.snapcopy.app.identity"
    private let account = "appUserId"

    func loadAppUserId() -> UUID? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data,
              let rawValue = String(data: data, encoding: .utf8) else {
            return nil
        }

        return UUID(uuidString: rawValue)
    }

    func saveAppUserId(_ id: UUID) {
        let data = Data(id.uuidString.utf8)
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(baseQuery() as CFDictionary, updateAttributes as CFDictionary)
        guard updateStatus != errSecSuccess else {
            return
        }

        var addQuery = baseQuery()
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

final class InMemoryUserIdentityStore: UserIdentityStoring {
    private var storedId: UUID?

    init(storedId: UUID? = nil) {
        self.storedId = storedId
    }

    func loadAppUserId() -> UUID? {
        storedId
    }

    func saveAppUserId(_ id: UUID) {
        storedId = id
    }
}
