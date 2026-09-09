import Foundation
import Observation
import MicKeeperCore

@MainActor @Observable final class UpdateChecker {
    enum State {
        case idle, checking, current, noRelease, available(URL), failure(String)
    }
    private(set) var state: State = .idle
    private let session: URLSession
    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 20
        session = URLSession(configuration: configuration)
    }
    func check() async {
        guard case .checking = state else {
            await performCheck(); return
        }
    }
    private func performCheck() async {
        state = .checking
        do {
            var request = URLRequest(url: URL(string: "https://api.github.com/repos/Roman-tex/MicKeeper/releases/latest")!)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("MicKeeper", forHTTPHeaderField: "User-Agent")
            request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ReleaseResponse.Failure.malformed }
            guard let release = try ReleaseResponse.decode(data: data, statusCode: http.statusCode) else {
                state = .noRelease; return
            }
            guard let current = ReleaseVersion(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") else {
                throw ReleaseResponse.Failure.malformed
            }
            state = release.version > current ? .available(release.url) : .current
        } catch let failure as ReleaseResponse.Failure {
            switch failure {
            case .rateLimited:
                state = .failure(L10n.text("about.update.rateLimited"))
            case .server(let code):
                state = .failure(L10n.format("about.update.server", String(code)))
            case .malformed:
                state = .failure(L10n.text("about.update.malformed"))
            }
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .failure(error.localizedDescription)
        }
    }
}
