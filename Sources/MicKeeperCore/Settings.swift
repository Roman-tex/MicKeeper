import Foundation

@MainActor public final class UserDefaultsKeeperSettings: KeeperSettings {
    private let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    public var selectedUID: String? {
        get { defaults.string(forKey: "selectedDeviceUID") }
        set { defaults.set(newValue, forKey: "selectedDeviceUID") }
    }
    public var selectedName: String? {
        get { defaults.string(forKey: "selectedDeviceName") }
        set { defaults.set(newValue, forKey: "selectedDeviceName") }
    }
    public var isEnabled: Bool {
        get { defaults.bool(forKey: "keeperEnabled") }
        set { defaults.set(newValue, forKey: "keeperEnabled") }
    }
}
