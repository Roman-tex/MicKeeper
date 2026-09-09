import Foundation

public struct AudioDevice: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public init(id: String, name: String) { self.id = id; self.name = name }
}

public struct AudioSnapshot: Sendable {
    public let devices: [AudioDevice]
    public let defaultUID: String?
    public init(devices: [AudioDevice], defaultUID: String?) {
        self.devices = devices; self.defaultUID = defaultUID
    }
}

@MainActor public protocol AudioHardware: AnyObject {
    func snapshot() throws -> AudioSnapshot
    func setDefaultInput(uid: String) throws
}

@MainActor public protocol KeeperSettings: AnyObject {
    var selectedUID: String? { get set }
    var selectedName: String? { get set }
    var isEnabled: Bool { get set }
}

@MainActor public protocol ScheduledAction: AnyObject { func cancel() }
@MainActor public protocol RetryScheduler {
    func schedule(after delay: TimeInterval, action: @escaping @MainActor () -> Void) -> any ScheduledAction
}

public enum KeeperIssue: Equatable, Sendable {
    case chooseDevice, deviceUnavailable, audioFailure(String), verificationFailed, conflict
}
