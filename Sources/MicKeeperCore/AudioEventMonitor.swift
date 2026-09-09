import CoreAudio
import Foundation

/// Only the C registration boundary is replaceable; subscription policy remains real in tests.
@MainActor public protocol AudioListenerBackend {
    func add(object: AudioObjectID, address: AudioObjectPropertyAddress, block: @escaping AudioObjectPropertyListenerBlock) -> OSStatus
    func remove(object: AudioObjectID, address: AudioObjectPropertyAddress, block: @escaping AudioObjectPropertyListenerBlock)
}
@MainActor public struct SystemAudioListenerBackend: AudioListenerBackend {
    public init() {}
    public func add(object: AudioObjectID, address: AudioObjectPropertyAddress, block: @escaping AudioObjectPropertyListenerBlock) -> OSStatus {
        var address = address
        guard AudioObjectHasProperty(object, &address) else { return kAudioHardwareUnknownPropertyError }
        return AudioObjectAddPropertyListenerBlock(object, &address, .main, block)
    }
    public func remove(object: AudioObjectID, address: AudioObjectPropertyAddress, block: @escaping AudioObjectPropertyListenerBlock) {
        var address = address
        _ = AudioObjectRemovePropertyListenerBlock(object, &address, .main, block)
    }
}

@MainActor public final class AudioEventMonitor {
    public enum Event: Sendable { case inputChanged, devicesChanged, serviceRestarted }
    public struct Failure: Error {
        public let status: OSStatus
    }
    private struct Listener {
        let object: AudioObjectID
        let address: AudioObjectPropertyAddress
        let block: AudioObjectPropertyListenerBlock
    }
    private let backend: any AudioListenerBackend
    private var listeners: [Listener] = []
    private var epoch = 0
    public init(backend: any AudioListenerBackend = SystemAudioListenerBackend()) { self.backend = backend }

    /// Device listeners are best-effort. A defective device must not tear down recovery events.
    public func start(devices: [AudioObjectID], onEvent: @escaping @MainActor (Event) -> Void) throws -> [OSStatus] {
        stop()
        do {
            try listen(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultInputDevice, event: .inputChanged, onEvent: onEvent)
            try listen(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDevices, event: .devicesChanged, onEvent: onEvent)
        } catch {
            stop(); throw error
        }
        var warnings: [OSStatus] = []
        do {
            try listen(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyServiceRestarted, event: .serviceRestarted, onEvent: onEvent)
        } catch let failure as Failure {
            // This property is documented but absent on some macOS releases. Wake and session notifications provide recovery there.
            if failure.status != kAudioHardwareUnknownPropertyError && failure.status != kAudioHardwareBadObjectError {
                warnings.append(failure.status)
            }
        } catch {
            warnings.append(kAudioHardwareUnspecifiedError)
        }
        for device in devices {
            for (selector, scope, event) in [
                (kAudioDevicePropertyDeviceIsAlive, kAudioObjectPropertyScopeGlobal, Event.devicesChanged),
                (kAudioObjectPropertyName, kAudioObjectPropertyScopeGlobal, Event.inputChanged),
                (kAudioDevicePropertyStreamConfiguration, kAudioObjectPropertyScopeInput, Event.devicesChanged)
            ] {
                do { try listen(device, selector, scope: scope, event: event, onEvent: onEvent) }
                catch let failure as Failure {
                    // Absent optional properties and already-removed devices are normal.
                    if failure.status != kAudioHardwareUnknownPropertyError && failure.status != kAudioHardwareBadObjectError {
                        warnings.append(failure.status)
                    }
                } catch { warnings.append(kAudioHardwareUnspecifiedError) }
            }
        }
        return warnings
    }
    private func listen(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector,
                        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                        event: Event, onEvent: @escaping @MainActor (Event) -> Void) throws {
        let address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
        let token = epoch
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self, self.epoch == token else { return }
                onEvent(event)
            }
        }
        let status = backend.add(object: object, address: address, block: block)
        guard status == noErr else { throw Failure(status: status) }
        listeners.append(Listener(object: object, address: address, block: block))
    }
    public func stop() {
        epoch += 1
        for listener in listeners {
            backend.remove(object: listener.object, address: listener.address, block: listener.block)
        }
        listeners.removeAll()
    }
}
