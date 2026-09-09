import CoreAudio
import Testing
@testable import MicKeeperCore

@MainActor final class FakeListenerBackend: AudioListenerBackend {
    struct Registration {
        let object: AudioObjectID
        let address: AudioObjectPropertyAddress
        let block: AudioObjectPropertyListenerBlock
    }
    var registrations: [Registration] = []
    var failsSystem = false
    var failsServiceRestart = false
    func add(object: AudioObjectID, address: AudioObjectPropertyAddress, block: @escaping AudioObjectPropertyListenerBlock) -> OSStatus {
        if object == kAudioObjectSystemObject,
           address.mSelector == kAudioHardwarePropertyServiceRestarted,
           failsServiceRestart { return kAudioHardwareUnknownPropertyError }
        if object == 7 || failsSystem { return kAudioHardwareIllegalOperationError }
        registrations.append(Registration(object: object, address: address, block: block))
        return noErr
    }
    func remove(object: AudioObjectID, address: AudioObjectPropertyAddress, block: @escaping AudioObjectPropertyListenerBlock) {
        registrations.removeAll { $0.object == object && $0.address.mSelector == address.mSelector }
    }
    func emitDeviceChange() {
        for r in registrations where r.object == kAudioObjectSystemObject && r.address.mSelector == kAudioHardwarePropertyDevices {
            var address = r.address; r.block(1, &address)
        }
    }
}

@Suite @MainActor struct AudioEventMonitorTests {
    @Test func badDeviceCannotDisableSystemRecoveryEvents() async throws {
        let backend = FakeListenerBackend(); let monitor = AudioEventMonitor(backend: backend)
        var received = 0
        let warnings = try monitor.start(devices: [7, 8]) { _ in received += 1 }
        #expect(!warnings.isEmpty)
        backend.emitDeviceChange()
        for _ in 0..<10 { await Task.yield() }
        #expect(received == 1)
        monitor.stop()
    }
    @Test func queuedCallbackFromOldSubscriptionIsIgnored() async throws {
        let backend = FakeListenerBackend(); let monitor = AudioEventMonitor(backend: backend)
        var received = 0
        _ = try monitor.start(devices: []) { _ in received += 1 }
        let old = try #require(backend.registrations.first)
        monitor.stop()
        var address = old.address; old.block(1, &address)
        for _ in 0..<10 { await Task.yield() }
        #expect(received == 0)
    }
    @Test func requiredListenerFailureIsReported() {
        let backend = FakeListenerBackend(); backend.failsSystem = true
        let monitor = AudioEventMonitor(backend: backend)
        #expect(throws: (any Error).self) { try monitor.start(devices: []) { _ in } }
    }
    @Test func unavailableServiceRestartPropertyDoesNotBlockMonitoring() throws {
        let backend = FakeListenerBackend(); backend.failsServiceRestart = true
        let monitor = AudioEventMonitor(backend: backend)
        let warnings = try monitor.start(devices: []) { _ in }
        #expect(warnings.isEmpty)
        #expect(backend.registrations.contains { $0.address.mSelector == kAudioHardwarePropertyDefaultInputDevice })
        #expect(backend.registrations.contains { $0.address.mSelector == kAudioHardwarePropertyDevices })
        monitor.stop()
    }
}
