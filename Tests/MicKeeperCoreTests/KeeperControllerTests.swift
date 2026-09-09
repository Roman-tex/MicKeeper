import Foundation
import Testing
@testable import MicKeeperCore

@MainActor final class FakeAudio: AudioHardware {
    var devices = [AudioDevice(id: "preferred", name: "USB Mic"), AudioDevice(id: "other", name: "Built-in")]
    var current: String? = "other"
    var writes: [String] = []
    var readFails = false
    var writeFails = false
    var ignoresWrite = false
    enum Failure: Error { case unavailable }
    func snapshot() throws -> AudioSnapshot {
        if readFails { throw Failure.unavailable }
        return AudioSnapshot(devices: devices, defaultUID: current)
    }
    func setDefaultInput(uid: String) throws {
        writes.append(uid)
        if writeFails { throw Failure.unavailable }
        if !ignoresWrite { current = uid }
    }
}
@MainActor final class MemorySettings: KeeperSettings {
    var selectedUID: String? = "preferred"
    var selectedName: String? = "USB Mic"
    var isEnabled = false
}
@MainActor final class ManualScheduler: RetryScheduler {
    final class Entry: ScheduledAction {
        let action: @MainActor () -> Void
        var cancelled = false
        init(_ action: @escaping @MainActor () -> Void) { self.action = action }
        func cancel() { cancelled = true }
    }
    var entries: [Entry] = []
    func schedule(after delay: TimeInterval, action: @escaping @MainActor () -> Void) -> any ScheduledAction {
        let entry = Entry(action); entries.append(entry); return entry
    }
    func runAll(includingCancelled: Bool = false) {
        var limit = 30
        while !entries.isEmpty && limit > 0 {
            limit -= 1
            let entry = entries.removeFirst()
            if !entry.cancelled || includingCancelled { entry.action() }
        }
    }
}
@MainActor struct Fixture {
    let audio = FakeAudio()
    let settings = MemorySettings()
    let scheduler = ManualScheduler()
    func controller() -> KeeperController {
        KeeperController(hardware: audio, settings: settings, scheduler: scheduler, now: { 100 })
    }
}

@Suite @MainActor struct KeeperControllerTests {
    @Test func enablingEnforcesPreferredInputAndAvoidsFeedbackWrites() {
        let f = Fixture(); let c = f.controller()
        c.setEnabled(true); c.refresh(); c.refresh()
        #expect(f.audio.writes == ["preferred"])
        #expect(c.isHolding)
        #expect(f.settings.isEnabled)
    }
    @Test func disabledControllerNeverWritesAndPreservesSelection() {
        let f = Fixture(); let c = f.controller()
        c.refresh(); c.select(f.audio.devices[1])
        #expect(f.audio.writes.isEmpty)
        #expect(c.selectedUID == "preferred")
        c.setEnabled(true); c.setEnabled(false)
        let count = f.audio.writes.count
        f.audio.current = "other"; c.refresh()
        #expect(f.audio.writes.count == count)
        #expect(c.selectedUID == "preferred")
        #expect(!c.isHolding)
    }
    @Test func unplugLeavesSystemAloneAndReconnectRestoresSelection() {
        let f = Fixture(); let c = f.controller()
        c.setEnabled(true)
        f.audio.devices.removeFirst(); f.audio.current = "other"; c.refresh()
        #expect(c.issue == .deviceUnavailable)
        #expect(c.isEnabled)
        #expect(f.audio.writes == ["preferred"])
        f.audio.devices.append(AudioDevice(id: "preferred", name: "Renamed USB")); c.refresh()
        #expect(f.audio.writes == ["preferred", "preferred"])
        #expect(c.selectedName == "Renamed USB")
        #expect(c.issue == nil)
    }
    @Test func cancelledRetriesCannotWriteAfterDisableEvenIfAlreadyQueued() {
        let f = Fixture(); f.audio.writeFails = true; let c = f.controller()
        c.setEnabled(true)
        #expect(f.audio.writes.count == 1)
        c.setEnabled(false); f.audio.writeFails = false
        f.scheduler.runAll(includingCancelled: true)
        #expect(f.audio.writes.count == 1)
    }
    @Test func changingSelectionInvalidatesOldRetries() {
        let f = Fixture(); f.audio.writeFails = true; let c = f.controller()
        c.setEnabled(true); f.audio.writeFails = false
        c.select(f.audio.devices[1]); f.scheduler.runAll(includingCancelled: true)
        #expect(c.selectedUID == "other")
        #expect(f.audio.writes == ["preferred"])
        #expect(f.settings.selectedUID == "other")
    }
    @Test func failedWritesHaveBoundedRetries() {
        let f = Fixture(); f.audio.writeFails = true; let c = f.controller()
        c.setEnabled(true); f.scheduler.runAll()
        #expect(f.audio.writes.count == 4)
        #expect(c.issue != nil)
        #expect(!c.isHolding)
    }
    @Test func successfulReturnWithoutActualSwitchIsNotSuccess() {
        let f = Fixture(); f.audio.ignoresWrite = true; let c = f.controller()
        c.setEnabled(true); f.scheduler.runAll()
        #expect(!c.isHolding)
        #expect(c.issue != nil)
        #expect(f.audio.writes.count == 4)
    }
    @Test func repeatedExternalOverridesTripConflictProtection() {
        let f = Fixture(); let c = f.controller(); c.setEnabled(true)
        for _ in 0..<12 { f.audio.current = "other"; c.refresh() }
        #expect(f.audio.writes.count == 5)
        #expect(c.issue == .conflict)
        c.retry()
        #expect(f.audio.writes.count == 6)
        #expect(c.isHolding)
    }
    @Test func enumerationFailureIsNotAnEmptyDeviceList() {
        let f = Fixture(); let c = f.controller(); c.refresh()
        f.audio.readFails = true; c.setEnabled(true); f.scheduler.runAll()
        #expect(c.devices.count == 2)
        #expect(c.issue != nil)
        #expect(f.audio.writes.isEmpty)
    }
    @Test func noDeviceCannotEnable() {
        let f = Fixture(); f.settings.selectedUID = nil
        f.audio.devices = []; f.audio.current = nil
        let c = f.controller(); c.setEnabled(true)
        #expect(!c.isEnabled)
        #expect(c.issue == .chooseDevice)
    }
    @Test func firstLaunchSuggestsCurrentDeviceWithoutEnforcing() {
        let f = Fixture(); f.settings.selectedUID = nil; f.settings.selectedName = nil
        let c = f.controller()
        #expect(c.selectedUID == "other")
        #expect(!c.isEnabled)
        #expect(f.audio.writes.isEmpty)
    }
    @Test func stopCancelsWithoutChangingPersistedLaunchPreference() {
        let f = Fixture(); f.audio.writeFails = true; let c = f.controller()
        c.setEnabled(true); c.stop(); f.scheduler.runAll(includingCancelled: true); c.refresh()
        #expect(f.settings.isEnabled)
        #expect(f.audio.writes.count == 1)
    }
    @Test func launchRestoresEnabledPreference() {
        let f = Fixture(); f.settings.isEnabled = true; let c = f.controller()
        #expect(c.isEnabled)
        #expect(f.audio.current == "preferred")
    }
}
