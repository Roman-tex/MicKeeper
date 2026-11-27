import AppKit
import Observation
import MicKeeperCore

@MainActor @Observable final class AppModel {
    let keeper: KeeperController
    let language = LanguageController()
    let login = LoginItemController()
    let updates = UpdateChecker()
    private enum MonitoringIssue {
        case warning
        case unavailable(OSStatus)
        case hardware(operationKey: String, status: OSStatus)
        case message(String)
    }
    private var monitoringIssue: MonitoringIssue?
    @ObservationIgnored private let hardware: CoreAudioHardware
    @ObservationIgnored private var restartTask: Task<Void, Never>?
    @ObservationIgnored private var stopped = false

    init() {
        let hardware = CoreAudioHardware()
        self.hardware = hardware
        keeper = KeeperController(hardware: hardware, settings: UserDefaultsKeeperSettings(), scheduler: TaskRetryScheduler())
        hardware.onEvent = { [weak self] event in
            guard let self, !self.stopped else { return }
            switch event {
            case .inputChanged: self.keeper.refresh()
            case .devicesChanged, .serviceRestarted: self.restartMonitoring()
            }
        }
        restartMonitoring()
        updates.start()
    }
    func restartMonitoring() {
        guard !stopped else { return }
        restartTask?.cancel()
        restartTask = Task { @MainActor [weak self] in
            for delay in [0.0, 0.25, 0.75, 1.5] {
                if delay > 0 {
                    do { try await Task.sleep(for: .seconds(delay)) } catch { return }
                }
                guard let self, !Task.isCancelled, !self.stopped else { return }
                do {
                    try self.hardware.startMonitoring()
                    self.monitoringIssue = self.hardware.monitoringWarning == nil ? nil : .warning
                    self.keeper.refresh()
                    return
                } catch let failure as CoreAudioHardware.Failure {
                    self.monitoringIssue = .hardware(operationKey: failure.operationKey, status: failure.status)
                } catch let failure as AudioEventMonitor.Failure {
                    self.monitoringIssue = .unavailable(failure.status)
                } catch {
                    self.monitoringIssue = .message(error.localizedDescription)
                }
            }
        }
    }
    func retry() { keeper.retry(); restartMonitoring() }
    func stop() {
        stopped = true
        restartTask?.cancel(); restartTask = nil
        keeper.stop(); hardware.stopMonitoring(); hardware.onEvent = nil
        updates.stop()
    }
    /// Disconnected devices are expected and recover on their own, so they read
    /// as waiting. Soft monitoring warnings keep the normal icon.
    var statusSymbol: StatusSymbol {
        guard keeper.isEnabled else { return .off }
        switch monitoringIssue {
        case .none, .warning: break
        case .unavailable, .hardware, .message: return .problem
        }
        switch keeper.issue {
        case .none: return .holding
        case .chooseDevice, .deviceUnavailable: return .waiting
        case .audioFailure, .verificationFailed: return .problem
        }
    }
    var issueMessage: String? {
        if let monitoringIssue {
            switch monitoringIssue {
            case .warning:
                return L10n.text("core.monitoringWarning")
            case .unavailable(let status):
                return L10n.format("error.monitoring.core", String(status))
            case .hardware(let operationKey, let status):
                let detail = "\(L10n.text(operationKey)) (Core Audio: \(status))"
                return L10n.format("error.audio", detail)
            case .message(let message):
                return L10n.format("error.monitoring", message)
            }
        }
        switch keeper.issue {
        case .none: return nil
        case .chooseDevice: return L10n.text("error.chooseDevice")
        case .deviceUnavailable: return L10n.text("error.deviceUnavailable")
        case .audioFailure(let message): return L10n.format("error.audio", message)
        case .verificationFailed: return L10n.text("error.verification")
        }
    }
}
