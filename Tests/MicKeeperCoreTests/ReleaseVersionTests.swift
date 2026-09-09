import Foundation
import Testing
@testable import MicKeeperCore

@Suite struct ReleaseVersionTests {
    @Test func comparesNumbersRatherThanStrings() throws {
        #expect(try #require(ReleaseVersion("v0.10.0")) > #require(ReleaseVersion("0.9.9")))
        #expect(ReleaseVersion("v1.0.0") == ReleaseVersion("1.0.0"))
    }
    @Test(arguments: ["", "1", "1.2", "1.2.3.4", "01.2.3", "1.2.-3", "1.0.0-beta.1", "1.2.3+build", "999999999999999999999.1.1"])
    func rejectsMalformedOrUnstableVersion(text: String) { #expect(ReleaseVersion(text) == nil) }
    private func data(tag: String = "v0.2.0", url: String = "https://github.com/Roman-tex/MicKeeper/releases/tag/v0.2.0", prerelease: Bool = false, draft: Bool = false) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["tag_name": tag, "html_url": url, "prerelease": prerelease, "draft": draft])
    }
    @Test func acceptsStableOfficialRelease() throws {
        let decoded = try ReleaseResponse.decode(data: data(), statusCode: 200)
        let release = try #require(decoded)
        #expect(release.version == ReleaseVersion("0.2.0"))
        #expect(release.url.absoluteString == "https://github.com/Roman-tex/MicKeeper/releases/tag/v0.2.0")
    }
    @Test func noPublishedReleaseIsDistinctFromFailure() throws {
        #expect(try ReleaseResponse.decode(data: Data(), statusCode: 404) == nil)
        #expect(throws: (any Error).self) { try ReleaseResponse.decode(data: data(), statusCode: 403) }
        #expect(throws: (any Error).self) { try ReleaseResponse.decode(data: data(), statusCode: 500) }
        #expect(throws: (any Error).self) { try ReleaseResponse.decode(data: Data("{}".utf8), statusCode: 200) }
    }
    @Test func neverOffersPrereleaseOrDraft() throws {
        #expect(try ReleaseResponse.decode(data: data(prerelease: true), statusCode: 200) == nil)
        #expect(try ReleaseResponse.decode(data: data(draft: true), statusCode: 200) == nil)
    }
    @Test(arguments: ["http://github.com/Roman-tex/MicKeeper/releases/tag/v0.2.0", "https://evil.example/app.dmg", "https://github.com/other/repo/releases/tag/v0.2.0", "file:///Applications/MicKeeper.app"])
    func rejectsUnexpectedReleaseDestination(url: String) throws {
        #expect(throws: (any Error).self) { try ReleaseResponse.decode(data: data(url: url), statusCode: 200) }
    }
}
