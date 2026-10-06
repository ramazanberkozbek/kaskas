import Foundation
import Testing
@testable import Kaskas

struct ActiveHoursTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return value
    }
    private func date(_ day: Int = 6, _ hour: Int, _ minute: Int = 0, calendar: Calendar? = nil) -> Date {
        (calendar ?? self.calendar).date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }
    private var schedule: ActiveHoursSchedule { ActiveHoursSchedule(isEnabled: true, endMinute: 18 * 60) }
    private var configuration: FocusConfiguration {
        FocusConfiguration(activeHours: schedule, focusDuration: 3600, microReminderInterval: 1200)
    }
    private func engine(at now: Date) -> SessionEngine {
        SessionEngine(configuration: configuration, now: now, calendar: calendar)
    }
    private func hasAutomaticAlert(_ effects: [SessionEffect]) -> Bool {
        effects.contains { effect in
            switch effect {
            case .showMicroReminder, .showBreakWarning, .showBreak, .showIdleBreakPrompt,
                 .showSkippedBreakReminder, .playBreakEndSound, .playBreakStartSound: true
            default: false
            }
        }
    }

    @Test func boundariesAreHalfOpenAndSkipWeekends() throws {
        #expect(schedule.state(at: date(6, 8, 59), calendar: calendar)?.isOutside == true)
        #expect(schedule.state(at: date(6, 9), calendar: calendar)?.isOutside == false)
        #expect(schedule.state(at: date(6, 17, 59), calendar: calendar)?.isOutside == false)
        #expect(schedule.state(at: date(6, 18), calendar: calendar)?.isOutside == true)
        #expect(schedule.state(at: date(9, 18), calendar: calendar)?.nextTransition == date(12, 9))
        #expect(schedule.state(at: date(10, 12), calendar: calendar)?.isOutside == true)
    }

    @Test func overnightIntervalsBelongToTheirStartingDay() {
        let night = ActiveHoursSchedule(isEnabled: true, weekdays: [6], startMinute: 22 * 60, endMinute: 6 * 60)
        #expect(night.state(at: date(9, 23), calendar: calendar)?.isOutside == false)
        #expect(night.state(at: date(10, 5, 59), calendar: calendar)?.isOutside == false)
        #expect(night.state(at: date(10, 6), calendar: calendar)?.isOutside == true)
        #expect(night.state(at: date(8, 23), calendar: calendar)?.isOutside == true)
    }

    @Test func daylightSavingUsesLocalDaysAndAnExplicitRepeatedHourPolicy() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        let night = ActiveHoursSchedule(isEnabled: true, weekdays: [7], startMinute: 22 * 60, endMinute: 6 * 60)
        let spring = cal.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 23))!
        let fall = cal.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 23))!
        #expect(night.state(at: spring, calendar: cal)?.window?.duration == TimeInterval(7 * 3600))
        #expect(night.state(at: fall, calendar: cal)?.window?.duration == TimeInterval(9 * 3600))
        let gap = ActiveHoursSchedule(isEnabled: true, weekdays: [1], startMinute: 150, endMinute: 240)
        let beforeGap = cal.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 1))!
        let next = try #require(gap.state(at: beforeGap, calendar: cal)?.nextTransition)
        #expect(cal.component(.hour, from: next) == 3)
        #expect(cal.component(.minute, from: next) == 0)
    }

    @Test func disabledAndInvalidPreferencesAreSafeAndOldSettingsDecode() throws {
        let defaultSchedule = ActiveHoursSchedule()
        #expect(!defaultSchedule.isEnabled)
        #expect(defaultSchedule.weekdays == [2, 3, 4, 5, 6])
        #expect(defaultSchedule.startMinute == 9 * 60)
        #expect(defaultSchedule.endMinute == 17 * 60)
        #expect(defaultSchedule.state(at: date(6, 12), calendar: calendar) == nil)
        #expect(ActiveHoursSchedule(startMinute: 540, endMinute: 540).isValid)
        #expect(ActiveHoursSchedule(startMinute: 540, endMinute: 540).isZeroDuration)
        #expect(ActiveHoursSchedule(isEnabled: true, startMinute: 540, endMinute: 540).state(at: date(6, 12), calendar: calendar)?.isOutside == true)
        #expect(ActiveHoursSchedule(isEnabled: true, startMinute: 540, endMinute: 540).state(at: date(6, 12), calendar: calendar)?.nextTransition == nil)
        #expect(!ActiveHoursSchedule(startMinute: -1, endMinute: 540).isValid)
        #expect(!ActiveHoursSchedule(startMinute: 540, endMinute: 1440).isValid)
        #expect(!FocusConfiguration(activeHours: .init(isEnabled: true, weekdays: [])).activeHours.isEnabled)
        let old = try JSONDecoder().decode(FocusConfiguration.self, from: Data("{}".utf8))
        #expect(!old.activeHours.isEnabled)
        var config = configuration
        config.activeHours.pausesTracking = true
        let decoded = try JSONDecoder().decode(FocusConfiguration.self, from: JSONEncoder().encode(config))
        #expect(config == decoded)
        let state = engine(at: date(6, 19)).state
        var oldState = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        oldState.removeValue(forKey: "activeHoursState")
        oldState.removeValue(forKey: "manualBreakActive")
        let restored = try JSONDecoder().decode(SessionState.self, from: JSONSerialization.data(withJSONObject: oldState))
        #expect(restored.activeHoursState == nil)
        #expect(restored.manualBreakActive == nil)
    }

    @Test func hoursSuppressRemindersWhileKeepingDefaultTracking() {
        var engine = engine(at: date(6, 8))
        #expect(engine.status.isOutsideActiveHours)
        #expect(engine.currentActivityKind(at: date(6, 8)) == .studying)
        #expect(engine.nextEventDate == date(6, 9))
        #expect(!hasAutomaticAlert(engine.send(.tick, at: date(6, 8, 59))))
        let opening = engine.send(.tick, at: date(6, 9))
        #expect(!hasAutomaticAlert(opening))
        #expect(!engine.status.isPaused)
        #expect(engine.session.endsAt == date(6, 10))
        #expect(engine.send(.tick, at: date(6, 9, 20)).contains(.showMicroReminder))
    }

    @Test func closingCancelsWarningAndDoesNotStartAnOverdueBreak() {
        var engine = engine(at: date(6, 17))
        #expect(engine.send(.tick, at: date(6, 17, 59)).contains(.showMicroReminder))
        let effects = engine.send(.tick, at: date(6, 18))
        #expect(!hasAutomaticAlert(effects))
        #expect(effects.contains(.dismissBreakWarning))
        #expect(effects.contains(.dismissMicroReminder))
        #expect(engine.status.isOutsideActiveHours)
        #expect(engine.nextEventDate == date(7, 9))
        #expect(engine.completedBreaks == 0)
    }

    @Test func manualPauseSurvivesScheduleTransitions() {
        var engine = engine(at: date(6, 17))
        engine.send(.setManualPause(active: true), at: date(6, 17, 30))
        engine.send(.tick, at: date(6, 18))
        #expect(engine.status.isManualPaused)
        #expect(engine.nextEventDate == date(7, 9))
        engine.send(.tick, at: date(7, 9))
        #expect(engine.status.isManualPaused)
        engine.send(.setManualPause(active: false), at: date(7, 9, 10))
        #expect(engine.session.endsAt == date(7, 10, 10))
    }

    @Test func meetingsAndIdleStillClassifyActivityOutsideHours() {
        var engine = engine(at: date(6, 19))
        engine.send(.setProtection(meetingActive: true, videoActive: false), at: date(6, 19))
        #expect(engine.status.isMeetingPaused)
        #expect(engine.currentActivityKind(at: date(6, 19)) == .meeting)
        engine.send(.setProtection(meetingActive: false, videoActive: false), at: date(6, 19, 5))
        #expect(engine.status.isOutsideActiveHours)
        engine.send(.beginIdle(startedAt: date(6, 19, 10)), at: date(6, 19, 10))
        #expect(engine.currentActivityKind(at: date(6, 19, 11)) == .computerInactive)
        #expect(!hasAutomaticAlert(engine.send(.idleReturned(returnedAt: date(6, 20)), at: date(6, 20))))
        #expect(engine.status.isOutsideActiveHours)
        #expect(engine.completedBreaks == 0)
    }

    @Test func trackingCanBeStoppedAndReenabledIndependentlyOfReminders() {
        var engine = engine(at: date(6, 19))
        var config = configuration
        config.activeHours.pausesTracking = true
        let effects = engine.send(.updateConfiguration(config), at: date(6, 19))
        #expect(engine.currentActivityKind(at: date(6, 19)) == .kaskasPaused)
        #expect(effects.contains(.persistSession(record: nil, activityKind: .kaskasPaused)))
        config.activeHours.pausesTracking = false
        engine.send(.updateConfiguration(config), at: date(6, 19, 1))
        #expect(engine.currentActivityKind(at: date(6, 19, 1)) == .studying)
        #expect(engine.status.isOutsideActiveHours)
        config.activeHours.isEnabled = false
        engine.send(.updateConfiguration(config), at: date(6, 19, 2))
        #expect(!engine.status.isPaused)
        #expect(engine.session.endsAt == date(6, 20, 2))
    }

    @Test func manualBreaksWorkOutsideHoursAndSurvivePersistence() throws {
        var engine = engine(at: date(6, 19))
        #expect(engine.send(.startBreakNow, at: date(6, 19)).contains(.showBreak(endsAt: date(6, 19, 5))))
        #expect(engine.manualBreakActive)
        let saved = try JSONDecoder().decode(SessionState.self, from: JSONEncoder().encode(engine.state))
        let restored = SessionEngine(configuration: configuration, restoredState: saved, now: date(6, 19, 1), calendar: calendar)
        #expect(restored.manualBreakActive)
        #expect(engine.send(.tick, at: date(6, 19, 5)).contains(.playBreakEndSound))
        engine.send(.userActivity, at: date(6, 19, 6))
        #expect(engine.status.isOutsideActiveHours)
        #expect(!engine.manualBreakActive)
    }

    @Test func automaticBreakClosesAtEndOfWindow() {
        var engine = engine(at: date(6, 17))
        engine.send(.startBreak(scheduled: true), at: date(6, 17, 58))
        let effects = engine.send(.tick, at: date(6, 18))
        #expect(effects.contains(.dismissBreak))
        #expect(!hasAutomaticAlert(effects))
        #expect(engine.status.isOutsideActiveHours)
    }

    @Test func nextDayRestoreStartsFreshWithoutOverdueAlerts() throws {
        let original = engine(at: date(6, 17))
        var restored = SessionEngine(configuration: configuration, restoredState: original.state,
                                     lastActiveAt: date(6, 17, 30), now: date(7, 10), calendar: calendar)
        let effects = restored.send(.launch, at: date(7, 10))
        #expect(!hasAutomaticAlert(effects))
        #expect(restored.session.endsAt == date(7, 11))
        #expect(restored.completedBreaks == 0)
    }

    @Test func wakingOutsideHoursDoesNotCreditAnAutomaticOvernightBreak() {
        var engine = engine(at: date(6, 19))
        engine.send(.sleep, at: date(6, 19))
        let effects = engine.send(.systemResumed, at: date(6, 21))
        #expect(!hasAutomaticAlert(effects))
        #expect(engine.status.isOutsideActiveHours)
        #expect(engine.completedBreaks == 0)
    }

    @Test func timezoneChangeReevaluatesTheSameInstant() {
        var engine = engine(at: date(6, 10))
        engine.activeHoursCalendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let effects = engine.send(.tick, at: date(6, 10))
        #expect(engine.status.isOutsideActiveHours)
        #expect(!hasAutomaticAlert(effects))
    }

    @Test func changingActiveHoursScheduleDuringSessionDoesNotResetActiveFocus() {
        var engine = engine(at: date(6, 10))
        let originalEndsAt = engine.session.endsAt
        let originalStartedAt = engine.session.startedAt

        var updated = configuration
        updated.activeHours = ActiveHoursSchedule(isEnabled: true, weekdays: [2, 3, 4, 5, 6], startMinute: 8 * 60, endMinute: 19 * 60)
        let effects = engine.send(.updateConfiguration(updated), at: date(6, 10, 15))

        #expect(!effects.contains(.dismissBreak))
        #expect(engine.session.startedAt == originalStartedAt)
        #expect(engine.session.endsAt == originalEndsAt)
        #expect(engine.session.phase == .focusing)
    }
}
