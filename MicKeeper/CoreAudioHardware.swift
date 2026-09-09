import CoreAudio
import Foundation
import OSLog
import MicKeeperCore

@MainActor final class CoreAudioHardware: AudioHardware {
    typealias Event = AudioEventMonitor.Event
    private let system = AudioObjectID(kAudioObjectSystemObject)
    private let logger = Logger(subsystem: "io.github.Roman-tex.MicKeeper", category: "CoreAudio")
    private let monitor = AudioEventMonitor()
    private(set) var monitoringWarning: String?
    var onEvent: ((Event) -> Void)?

    struct Failure: LocalizedError {
        let operationKey: String
        let status: OSStatus
        var errorDescription: String? { "\(L10n.text(operationKey)) (Core Audio: \(status))." }
    }
    private func address(_ selector: AudioObjectPropertySelector,
                         scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }
    private func check(_ status: OSStatus, _ operationKey: String) throws {
        guard status == noErr else {
            logger.error("\(operationKey, privacy: .public): \(status)")
            throw Failure(operationKey: operationKey, status: status)
        }
    }
    private func uint32(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector,
                        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) throws -> UInt32 {
        var property = address(selector, scope: scope)
        var result: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        try check(AudioObjectGetPropertyData(object, &property, 0, nil, &size, &result), "core.error.readProperty")
        guard size == MemoryLayout<UInt32>.size else {
            throw Failure(operationKey: "core.error.badPropertySize", status: kAudioHardwareBadPropertySizeError)
        }
        return result
    }
    private func string(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) throws -> String {
        var property = address(selector)
        var result: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = withUnsafeMutablePointer(to: &result) {
            AudioObjectGetPropertyData(object, &property, 0, nil, &size, $0)
        }
        try check(status, "core.error.readName")
        guard let result else {
            throw Failure(operationKey: "core.error.emptyProperty", status: kAudioHardwareUnspecifiedError)
        }
        return result.takeRetainedValue() as String
    }
    private func deviceIDs() throws -> [AudioDeviceID] {
        var property = address(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        try check(AudioObjectGetPropertyDataSize(system, &property, 0, nil, &size), "core.error.list")
        guard size > 0 else { return [] }
        guard size % UInt32(MemoryLayout<AudioDeviceID>.stride) == 0 else {
            throw Failure(operationKey: "core.error.badDeviceList", status: kAudioHardwareBadPropertySizeError)
        }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.stride)
        let capacity = size
        let status = ids.withUnsafeMutableBytes {
            AudioObjectGetPropertyData(system, &property, 0, nil, &size, $0.baseAddress!)
        }
        try check(status, "core.error.readList")
        guard size <= capacity, size % 4 == 0 else {
            throw Failure(operationKey: "core.error.changedList", status: kAudioHardwareBadPropertySizeError)
        }
        return Array(ids.prefix(Int(size) / MemoryLayout<AudioDeviceID>.stride))
    }
    private func hasInput(_ device: AudioDeviceID) throws -> Bool {
        var property = address(kAudioDevicePropertyStreamConfiguration, scope: kAudioObjectPropertyScopeInput)
        var size: UInt32 = 0
        try check(AudioObjectGetPropertyDataSize(device, &property, 0, nil, &size), "core.error.channels")
        guard size > 0 else { return false }
        let offset = MemoryLayout<AudioBufferList>.offset(of: \.mBuffers)!
        guard Int(size) >= offset else {
            throw Failure(operationKey: "core.error.badChannels", status: kAudioHardwareBadPropertySizeError)
        }
        let capacity = Int(size)
        let raw = UnsafeMutableRawPointer.allocate(byteCount: max(capacity, MemoryLayout<AudioBufferList>.size),
                                                   alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        try check(AudioObjectGetPropertyData(device, &property, 0, nil, &size, raw), "core.error.readChannels")
        guard Int(size) <= capacity, Int(size) >= offset else {
            throw Failure(operationKey: "core.error.changedChannels", status: kAudioHardwareBadPropertySizeError)
        }
        let list = raw.assumingMemoryBound(to: AudioBufferList.self)
        guard Int(list.pointee.mNumberBuffers) <= (Int(size) - offset) / MemoryLayout<AudioBuffer>.stride else {
            throw Failure(operationKey: "core.error.badBuffers", status: kAudioHardwareBadPropertySizeError)
        }
        return UnsafeMutableAudioBufferListPointer(list).contains { $0.mNumberChannels > 0 }
    }
    private func inputDevices() throws -> [(AudioDeviceID, AudioDevice)] {
        var result: [(AudioDeviceID, AudioDevice)] = []
        for id in try deviceIDs() {
            do {
                guard try hasInput(id),
                      try uint32(id, kAudioDevicePropertyDeviceIsAlive) != 0,
                      try uint32(id, kAudioDevicePropertyDeviceCanBeDefaultDevice, scope: kAudioObjectPropertyScopeInput) != 0 else { continue }
                let uid = try string(id, kAudioDevicePropertyDeviceUID)
                guard !uid.isEmpty else { continue }
                result.append((id, AudioDevice(id: uid, name: try string(id, kAudioObjectPropertyName))))
            } catch let failure as Failure where failure.status == kAudioHardwareBadObjectError {
                // A device can disappear between enumeration and its property reads.
                continue
            }
        }
        return result.sorted {
            let order = $0.1.name.localizedStandardCompare($1.1.name)
            return order == .orderedSame ? $0.1.id < $1.1.id : order == .orderedAscending
        }
    }
    func snapshot() throws -> AudioSnapshot {
        let devices = try inputDevices()
        let currentID = try uint32(system, kAudioHardwarePropertyDefaultInputDevice)
        return AudioSnapshot(devices: devices.map(\.1), defaultUID: devices.first { $0.0 == currentID }?.1.id)
    }
    func setDefaultInput(uid: String) throws {
        // Resolve UID again: numerical object IDs are not stable across reconnections.
        guard var id = try inputDevices().first(where: { $0.1.id == uid })?.0 else {
            throw Failure(operationKey: "core.error.disconnected", status: kAudioHardwareBadDeviceError)
        }
        var property = address(kAudioHardwarePropertyDefaultInputDevice)
        var settable: DarwinBoolean = false
        try check(AudioObjectIsPropertySettable(system, &property, &settable), "core.error.checkSettable")
        guard settable.boolValue else {
            throw Failure(operationKey: "core.error.notSettable", status: kAudioHardwareIllegalOperationError)
        }
        try check(AudioObjectSetPropertyData(system, &property, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &id),
                  "core.error.setInput")
    }
    func startMonitoring() throws {
        let warnings = try monitor.start(devices: deviceIDs()) { [weak self] event in
            self?.onEvent?(event)
        }
        monitoringWarning = warnings.isEmpty ? nil : L10n.text("core.monitoringWarning")
        for status in warnings { logger.warning("Device listener registration returned \(status)") }
    }
    func stopMonitoring() { monitor.stop() }
}
