import Foundation
import Testing
@testable import MicKeeperCore

@MainActor private final class UpdatePreferences: AutomaticUpdateSettings {
    var isEnabled = true
    var lastAttempt: Date?
}

@Suite @MainActor struct UpdateCheckScheduleTests {
    @Test func firstLaunchChecksOnceAndSchedulesTomorrow() throws {
        let settings = UpdatePreferences(); let scheduler = ManualScheduler()
        let time = Date(timeIntervalSince1970: 100_000)
        let schedule = UpdateCheckSchedule(settings: settings, scheduler: scheduler, now: { time })
        var checks = 0
        schedule.start { checks += 1 }
        let first = try #require(scheduler.entries.last)
        #expect(first.delay == 0)
        first.action()
        #expect(checks == 1)
        #expect(settings.lastAttempt == time)
        #expect(scheduler.entries.last?.delay == 86_400)
    }
    @Test func relaunchHonorsPersistedAttemptEvenAfterFailure() throws {
        let settings = UpdatePreferences(); let scheduler = ManualScheduler()
        let time = Date(timeIntervalSince1970: 100_000)
        settings.lastAttempt = time.addingTimeInterval(-3_600)
        let schedule = UpdateCheckSchedule(settings: settings, scheduler: scheduler, now: { time })
        schedule.start {}
        #expect(try #require(scheduler.entries.last).delay == 82_800)
    }
    @Test func disabledPreferenceMakesNoRequestAndCanBeEnabled() {
        let settings = UpdatePreferences(); settings.isEnabled = false
        let scheduler = ManualScheduler()
        let schedule = UpdateCheckSchedule(settings: settings, scheduler: scheduler)
        schedule.start { Issue.record("Disabled schedule must not check") }
        #expect(scheduler.entries.isEmpty)
        schedule.setEnabled(true)
        #expect(settings.isEnabled)
        #expect(scheduler.entries.last?.delay == 0)
    }
    @Test func disablingRejectsAlreadyQueuedCallback() throws {
        let settings = UpdatePreferences(); let scheduler = ManualScheduler()
        let schedule = UpdateCheckSchedule(settings: settings, scheduler: scheduler)
        var checks = 0
        schedule.start { checks += 1 }
        let old = try #require(scheduler.entries.last)
        schedule.setEnabled(false)
        old.action()
        #expect(!settings.isEnabled)
        #expect(checks == 0)
        #expect(settings.lastAttempt == nil)
    }
    @Test func manualCheckPostponesAutomaticCheck() throws {
        let settings = UpdatePreferences(); let scheduler = ManualScheduler()
        let schedule = UpdateCheckSchedule(settings: settings, scheduler: scheduler)
        var checks = 0
        schedule.start { checks += 1 }
        let old = try #require(scheduler.entries.last)
        schedule.recordAttempt()
        old.action()
        #expect(checks == 0)
        #expect(scheduler.entries.last?.delay ?? 0 > 86_399)
    }
    @Test func wakeChecksOverdueAttemptWithoutWaitingAnotherDay() {
        let settings = UpdatePreferences(); let scheduler = ManualScheduler()
        var time = Date(timeIntervalSince1970: 100_000)
        settings.lastAttempt = time
        let schedule = UpdateCheckSchedule(settings: settings, scheduler: scheduler, now: { time })
        schedule.start {}
        time.addTimeInterval(90_000)
        schedule.refresh()
        #expect(scheduler.entries.last?.delay == 0)
    }
    @Test func stopCancelsCallbacksWithoutChangingPreference() throws {
        let settings = UpdatePreferences(); let scheduler = ManualScheduler()
        let schedule = UpdateCheckSchedule(settings: settings, scheduler: scheduler)
        var checks = 0
        schedule.start { checks += 1 }
        let old = try #require(scheduler.entries.last)
        schedule.stop()
        old.action()
        #expect(checks == 0)
        #expect(settings.isEnabled)
    }
}
