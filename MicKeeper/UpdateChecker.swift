import Foundation
import Observation
import MicKeeperCore

@MainActor @Observable final class UpdateChecker {
    enum State {
        case idle, checking, current, noRelease, available(URL), failure(String)
    }
    private(set) var state: State = .idle
    private(set) var isChecking = false
    let automatic = UpdateCheckSchedule(settings: UserDefaultsAutomaticUpdateSettings())
    @ObservationIgnored private let session: URLSession
    @ObservationIgnored private var automaticTask: Task<Void, Never>?
    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 20
        session = URLSession(configuration: configuration)
    }
    func start() {
        automatic.start { [weak self] in
            guard let self, !self.isChecking else { return }
            self.automaticTask = Task { @MainActor [weak self] in
                guard let self else { return }
                await self.performCheck(isAutomatic: true)
                self.automaticTask = nil
            }
        }
    }
    func setAutomaticEnabled(_ value: Bool) {
        automatic.setEnabled(value)
        if !value { automaticTask?.cancel() }
    }
    func stop() {
        automatic.stop()
        automaticTask?.cancel()
        automaticTask = nil
    }
    func check() async {
        guard !isChecking else { return }
        automatic.recordAttempt()
        await performCheck(isAutomatic: false)
    }
    private func performCheck(isAutomatic: Bool) async {
        guard !isChecking, !Task.isCancelled else { return }
        let previousState = state
        isChecking = true
        if !isAutomatic { state = .checking }
        defer { isChecking = false }
        let result: State
        do {
            var request = URLRequest(url: URL(string: "https://api.github.com/repos/Roman-tex/MicKeeper/releases/latest")!)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("MicKeeper", forHTTPHeaderField: "User-Agent")
            request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ReleaseResponse.Failure.malformed }
            if let release = try ReleaseResponse.decode(data: data, statusCode: http.statusCode) {
                guard let current = ReleaseVersion(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") else {
                    throw ReleaseResponse.Failure.malformed
                }
                result = release.version > current ? .available(release.url) : .current
            } else {
                result = .noRelease
            }
        } catch let failure as ReleaseResponse.Failure {
            switch failure {
            case .rateLimited:
                result = .failure(L10n.text("about.update.rateLimited"))
            case .server(let code):
                result = .failure(L10n.format("about.update.server", String(code)))
            case .malformed:
                result = .failure(L10n.text("about.update.malformed"))
            }
        } catch {
            result = .failure(error.localizedDescription)
        }
        guard !Task.isCancelled else {
            if !isAutomatic { state = previousState }
            return
        }
        if isAutomatic {
            guard automatic.isEnabled else { return }
            // Background failures are quiet and preserve an already found release.
            if case .failure = result { return }
        }
        state = result
    }
}
