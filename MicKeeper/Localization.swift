import Foundation

enum L10n {
    private static let languageOverrideKey = "languageOverride"

    static func text(_ key: String) -> String {
        NSLocalizedString(key, bundle: bundle, comment: "")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: Locale.current, arguments: arguments)
    }

    private static var bundle: Bundle {
        guard let identifier = UserDefaults.standard.string(forKey: languageOverrideKey),
              let path = Bundle.main.path(forResource: identifier, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return .main }
        return bundle
    }
}
