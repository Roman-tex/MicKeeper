import Foundation
import Observation

@MainActor public protocol AutomaticUpdateSettings: AnyObject {
    var isEnabled: Bool { get set }
    var lastAttempt: Date? { get set }
}

@MainActor @Observable public final class UpdateCheckSchedule {
    public private(set) var isEnabled: Bool
    @ObservationIgnored private let settings: any AutomaticUpdateSettings
    @ObservationIgnored private let scheduler: any RetryScheduler
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var onCheck: (@MainActor () -> Void)?
    @ObservationIgnored private var pending: (any ScheduledAction)?
    @ObservationIgnored private var generation = 0
    private let interval: TimeInterval = 86_400

    public init(settings: any AutomaticUpdateSettings, scheduler: any RetryScheduler = TaskRetryScheduler(),
                now: @escaping () -> Date = Date.init) {
        self.settings = settings; self.scheduler = scheduler; self.now = now
        isEnabled = settings.isEnabled
    }
    public func start(onCheck: @escaping @MainActor () -> Void) {
        self.onCheck = onCheck
        refresh()
    }
    public func setEnabled(_ value: Bool) {
        isEnabled = value; settings.isEnabled = value
        refresh()
    }
    public func recordAttempt() {
        // Failed requests count too: an offline connection must not cause a loop.
        settings.lastAttempt = now()
        refresh()
    }
    public func refresh() {
        generation += 1
        pending?.cancel(); pending = nil
        guard isEnabled, onCheck != nil else { return }
        let date = now()
        let delay: TimeInterval
        if let last = settings.lastAttempt, last <= date {
            delay = max(0, interval - date.timeIntervalSince(last))
        } else {
            // A first launch or a clock moved backwards should not defer forever.
            delay = 0
        }
        let expectedGeneration = generation
        pending = scheduler.schedule(after: delay) { [weak self] in
            guard let self, self.isEnabled, self.generation == expectedGeneration,
                  let onCheck = self.onCheck else { return }
            self.pending = nil
            self.recordAttempt()
            onCheck()
        }
    }
    public func stop() {
        onCheck = nil
        refresh()
    }
}

@MainActor public final class UserDefaultsAutomaticUpdateSettings: AutomaticUpdateSettings {
    private let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    public var isEnabled: Bool {
        get { defaults.object(forKey: "automaticUpdateChecks") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "automaticUpdateChecks") }
    }
    public var lastAttempt: Date? {
        get { defaults.object(forKey: "lastUpdateCheckAttempt") as? Date }
        set { defaults.set(newValue, forKey: "lastUpdateCheckAttempt") }
    }
}
