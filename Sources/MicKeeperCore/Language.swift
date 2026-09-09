import Foundation

/// Languages whose interface resources are bundled with the app.
public enum AppLanguage: String, CaseIterable, Sendable {
    case english = "en"
    case russian = "ru"
    case ukrainian = "uk"
    case german = "de"
    case spanish = "es"
    case simplifiedChinese = "zh-Hans"

    /// The language's own name, so the picker remains understandable after switching.
    public var nativeName: String {
        switch self {
        case .english: "English"
        case .russian: "Русский"
        case .ukrainian: "Українська"
        case .german: "Deutsch"
        case .spanish: "Español"
        case .simplifiedChinese: "简体中文"
        }
    }
}
