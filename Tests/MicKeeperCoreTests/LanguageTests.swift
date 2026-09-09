import Testing
@testable import MicKeeperCore

@Suite struct LanguageTests {
    @Test func supportedLanguagesIncludeSimplifiedChinese() {
        #expect(AppLanguage.allCases.contains(.simplifiedChinese))
        #expect(AppLanguage.simplifiedChinese.nativeName == "简体中文")
    }

    @Test func unsupportedIdentifiersDoNotBecomeSupportedLanguages() {
        #expect(AppLanguage(rawValue: "fr") == nil)
        #expect(AppLanguage(rawValue: "zh-Hant") == nil)
        #expect(AppLanguage(rawValue: "zh-Hans") == .simplifiedChinese)
    }
}
