import Foundation

public struct ReleaseVersion: Comparable, Sendable {
    private let components: [UInt]
    public init?(_ text: String) {
        let value = text.hasPrefix("v") ? String(text.dropFirst()) : text
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        var numbers: [UInt] = []
        for part in parts {
            guard !part.isEmpty, part.allSatisfy({ $0.isASCII && $0.isNumber }),
                  part.count == 1 || part.first != "0", let number = UInt(part) else { return nil }
            numbers.append(number)
        }
        components = numbers
    }
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.components.lexicographicallyPrecedes(rhs.components)
    }
}

public struct ReleaseResponse: Sendable {
    public let version: ReleaseVersion
    public let url: URL

    public enum Failure: Error {
        case rateLimited, server(Int), malformed
    }
    private struct Payload: Decodable {
        let tag_name: String
        let html_url: String
        let prerelease: Bool
        let draft: Bool
    }
    public static func decode(data: Data, statusCode: Int) throws -> Self? {
        if statusCode == 404 { return nil }
        if statusCode == 403 || statusCode == 429 { throw Failure.rateLimited }
        guard statusCode == 200 else { throw Failure.server(statusCode) }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else { throw Failure.malformed }
        guard !payload.prerelease, !payload.draft else { return nil }
        guard let version = ReleaseVersion(payload.tag_name),
              let components = URLComponents(string: payload.html_url),
              components.scheme == "https", components.host == "github.com",
              components.user == nil, components.password == nil, components.port == nil,
              components.query == nil, components.fragment == nil,
              components.path == "/Roman-tex/MicKeeper/releases/tag/\(payload.tag_name)",
              let url = components.url else { throw Failure.malformed }
        return Self(version: version, url: url)
    }
}
