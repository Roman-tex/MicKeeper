import Foundation
import Observation
import MicKeeperCore

@MainActor @Observable final class LanguageController {
    static let systemIdentifier = "system"
    private static let defaultsKey = "languageOverride"
    private let defaults: UserDefaults
    private(set) var override: AppLanguage?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let rawValue = defaults.string(forKey: Self.defaultsKey),
           let language = AppLanguage(rawValue: rawValue) {
            override = language
        } else {
            override = nil
            if defaults.string(forKey: Self.defaultsKey) != nil {
                defaults.removeObject(forKey: Self.defaultsKey)
            }
        }
    }

    var selectedIdentifier: String {
        override?.rawValue ?? Self.systemIdentifier
    }

    func setSelection(_ identifier: String) {
        let next = identifier == Self.systemIdentifier ? nil : AppLanguage(rawValue: identifier)
        guard next != override else { return }
        override = next
        if let next {
            defaults.set(next.rawValue, forKey: Self.defaultsKey)
        } else {
            defaults.removeObject(forKey: Self.defaultsKey)
        }
    }
}
