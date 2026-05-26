import Foundation

final class ShareCardTemplateStore {
    private let storageKey = "snapcopy.shareCardTemplate"
    private let defaults: UserDefaults
    private let repository: ShareCardTemplateRepository

    init(
        defaults: UserDefaults = .standard,
        repository: ShareCardTemplateRepository = ShareCardTemplateRepository()
    ) {
        self.defaults = defaults
        self.repository = repository
    }

    func load() -> ShareCardTemplate {
        guard
            let rawValue = defaults.string(forKey: storageKey),
            let template = ShareCardTemplate(rawValue: rawValue)
        else {
            return repository.fallbackTemplate()
        }

        return template
    }

    func save(_ template: ShareCardTemplate) {
        defaults.set(template.rawValue, forKey: storageKey)
    }
}
