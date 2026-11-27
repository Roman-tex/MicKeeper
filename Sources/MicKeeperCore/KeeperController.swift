import Foundation
import Observation

/// Owns policy only. Core Audio, preferences and time are supplied at the boundary.
@MainActor @Observable public final class KeeperController {
    public private(set) var devices: [AudioDevice] = []
    public private(set) var selectedUID: String?
    public private(set) var selectedName: String?
    public private(set) var isEnabled: Bool
    public private(set) var issue: KeeperIssue?
    public private(set) var isHolding = false
    /// Number of verified switches back to the selected input since launch.
    public private(set) var restorations = 0

    @ObservationIgnored private let hardware: any AudioHardware
    @ObservationIgnored private let settings: any KeeperSettings
    @ObservationIgnored private let scheduler: any RetryScheduler
    @ObservationIgnored private let now: () -> TimeInterval
    @ObservationIgnored private var pending: (any ScheduledAction)?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var stopped = false
    @ObservationIgnored private var writeTimes: [TimeInterval] = []
    private let maximumWritesPerWindow = 5
    private let writeWindow: TimeInterval = 10
    private let retryDelays: [TimeInterval] = [0.25, 0.75, 1.5]

    public init(hardware: any AudioHardware, settings: any KeeperSettings,
                scheduler: any RetryScheduler, now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.hardware = hardware; self.settings = settings
        self.scheduler = scheduler; self.now = now
        selectedUID = settings.selectedUID; selectedName = settings.selectedName
        isEnabled = settings.isEnabled && settings.selectedUID != nil
        refresh()
    }

    public func setEnabled(_ value: Bool) {
        guard !stopped else { return }
        invalidatePending()
        writeTimes.removeAll()
        if value && selectedUID == nil {
            refresh()
            guard selectedUID != nil else { issue = .chooseDevice; return }
        }
        isEnabled = value; settings.isEnabled = value
        isHolding = false; issue = nil
        refresh()
    }

    public func select(_ device: AudioDevice) {
        guard isEnabled, !stopped, devices.contains(where: { $0.id == device.id }) else { return }
        invalidatePending()
        saveSelection(device)
        writeTimes.removeAll()
        refresh()
    }

    public func refresh() {
        guard !stopped else { return }
        // Events can repeat while a device is applying a change. Read the latest
        // state, but keep the existing retry deadline instead of writing again.
        reconcile(attempt: 0, canWrite: pending == nil)
    }

    public func retry() {
        guard !stopped else { return }
        invalidatePending()
        writeTimes.removeAll()
        refresh()
    }

    /// Stops writes without altering the preference restored on the next launch.
    public func stop() {
        stopped = true; isHolding = false
        invalidatePending()
    }

    private func saveSelection(_ device: AudioDevice) {
        selectedUID = device.id; selectedName = device.name
        settings.selectedUID = device.id; settings.selectedName = device.name
    }

    private func invalidatePending() {
        generation += 1
        pending?.cancel(); pending = nil
    }

    private func reconcile(attempt: Int, canWrite: Bool = true) {
        guard !stopped else { return }
        isHolding = false
        do {
            let snapshot = try hardware.snapshot()
            devices = snapshot.devices
            if selectedUID == nil, let suggestion = devices.first(where: { $0.id == snapshot.defaultUID }) ?? devices.first {
                saveSelection(suggestion)
            }
            if let selected = devices.first(where: { $0.id == selectedUID }) {
                saveSelection(selected)
            }
            guard isEnabled else { invalidatePending(); issue = nil; return }
            guard let uid = selectedUID else { issue = .chooseDevice; return }
            guard devices.contains(where: { $0.id == uid }) else {
                invalidatePending()
                issue = .deviceUnavailable; return
            }
            if snapshot.defaultUID == uid {
                invalidatePending()
                issue = nil; isHolding = true; return
            }
            guard canWrite else { return }

            let timestamp = now()
            writeTimes.removeAll { timestamp - $0 >= writeWindow }
            if writeTimes.count >= maximumWritesPerWindow, let oldest = writeTimes.first {
                // Limit write bursts without permanently abandoning the user's
                // choice or claiming to know which process changed the input.
                issue = nil
                scheduleReconciliation(after: max(0.01, oldest + writeWindow - timestamp), attempt: 0)
                return
            }
            writeTimes.append(timestamp)
            try hardware.setDefaultInput(uid: uid)
            let verified = try hardware.snapshot()
            devices = verified.devices
            guard verified.defaultUID == uid else {
                throw VerificationFailure()
            }
            restorations += 1
            issue = nil; isHolding = true
        } catch {
            issue = error is VerificationFailure ? .verificationFailed : .audioFailure(error.localizedDescription)
            guard canWrite, isEnabled, attempt < retryDelays.count else { return }
            scheduleReconciliation(after: retryDelays[attempt], attempt: attempt + 1)
        }
    }

    private func scheduleReconciliation(after delay: TimeInterval, attempt: Int) {
        let expectedGeneration = generation
        pending = scheduler.schedule(after: delay) { [weak self] in
            guard let self, !self.stopped, self.isEnabled,
                  self.generation == expectedGeneration else { return }
            self.pending = nil
            self.reconcile(attempt: attempt)
        }
    }

    private struct VerificationFailure: Error {}
}
