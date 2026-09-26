import Foundation
import Testing
@testable import Kaskas

struct SessionEngineTests {
    private let startDate = Date(timeIntervalSinceReferenceDate: 1_000_000)
    private let configuration = FocusConfiguration(
        focusDuration: 45 * 60,
        microReminderInterval: 20 * 60,
        breakDuration: 5 * 60,
        snoozeDuration: 5 * 60
    )

    @Test
    func startsWithDateBasedDeadlines() {
        let engine = SessionEngine(configuration: configuration, now: startDate)

        #expect(engine.session.phase == .focusing)
        #expect(engine.session.endsAt == startDate.addingTimeInterval(45 * 60))
        #expect(engine.session.nextMicroReminderAt == startDate.addingTimeInterval(20 * 60))
    }

    @Test
    func emitsMicroRemindersWithoutStartingABreak() {
        var engine = SessionEngine(configuration: configuration, now: startDate)

        let firstEvents = engine.process(at: startDate.addingTimeInterval(20 * 60))
        let secondEvents = engine.process(at: startDate.addingTimeInterval(40 * 60))

        #expect(firstEvents == [.microReminderDue])
        #expect(secondEvents == [.microReminderDue])
        #expect(engine.session.phase == .focusing)
        #expect(engine.session.nextMicroReminderAt == nil)
    }

    @Test
    func doesNotReplayMissedMicroRemindersAfterWake() {
        var engine = SessionEngine(configuration: configuration, now: startDate)

        let events = engine.process(at: startDate.addingTimeInterval(41 * 60))
        let repeatedEvents = engine.process(at: startDate.addingTimeInterval(41 * 60))

        #expect(events == [.microReminderDue])
        #expect(repeatedEvents.isEmpty)
    }

    @Test
    func startsFullBreakAtFocusDeadline() {
        var engine = SessionEngine(configuration: configuration, now: startDate)
        let deadline = startDate.addingTimeInterval(45 * 60)

        let events = engine.process(at: deadline)

        #expect(events == [.fullBreakDue])
        #expect(engine.session.phase == .onBreak)
        #expect(engine.session.startedAt == deadline)
        #expect(engine.session.endsAt == deadline.addingTimeInterval(5 * 60))
    }

    @Test
    func warnsTwentySecondsBeforeBreakOnlyOnce() {
        var engine = SessionEngine(configuration: configuration, now: startDate)
        let warningAt = startDate.addingTimeInterval(44 * 60 + 40)

        #expect(engine.nextEventDate == startDate.addingTimeInterval(20 * 60))
        _ = engine.process(at: startDate.addingTimeInterval(20 * 60))
        _ = engine.process(at: startDate.addingTimeInterval(40 * 60))
        #expect(engine.nextEventDate == warningAt)
        #expect(engine.process(at: warningAt.addingTimeInterval(-1)).isEmpty)
        #expect(engine.process(at: warningAt) == [.breakApproaching])
        #expect(engine.process(at: warningAt).isEmpty)
        #expect(engine.nextEventDate == startDate.addingTimeInterval(45 * 60))
    }

    @Test
    func meetingDefersWarningAndBreakUntilAfterCall() {
        var engine = SessionEngine(configuration: configuration, now: startDate)
        let meetingStart = startDate.addingTimeInterval(44 * 60 + 30)
        let meetingEnd = meetingStart.addingTimeInterval(10 * 60)

        _ = engine.process(at: startDate.addingTimeInterval(20 * 60))
        _ = engine.process(at: startDate.addingTimeInterval(40 * 60))
        engine.beginMeetingPause(at: meetingStart)
        let remaining = engine.snapshot(at: meetingEnd).remaining
        #expect(remaining == 30)
        #expect(engine.nextEventDate == nil)
        #expect(engine.process(at: meetingEnd).isEmpty)
        #expect(engine.session.phase == .focusing)

        engine.endMeetingPause(at: meetingEnd)
        #expect(engine.snapshot(at: meetingEnd).remaining == 90)
        #expect(engine.process(at: meetingEnd.addingTimeInterval(69)).isEmpty)
        #expect(engine.process(at: meetingEnd.addingTimeInterval(70)) == [.breakApproaching])
        #expect(engine.process(at: meetingEnd.addingTimeInterval(90)) == [.fullBreakDue])
    }

    @Test
    func repeatedMeetingSamplesDoNotExtendPauseTwice() {
        var engine = SessionEngine(configuration: configuration, now: startDate)
        let meetingStart = startDate.addingTimeInterval(5 * 60)
        let meetingEnd = meetingStart.addingTimeInterval(10 * 60)

        engine.beginMeetingPause(at: meetingStart)
        engine.beginMeetingPause(at: meetingStart.addingTimeInterval(2 * 60))
        engine.endMeetingPause(at: meetingEnd)
        let endDate = engine.session.endsAt
        engine.endMeetingPause(at: meetingEnd.addingTimeInterval(20))

        #expect(endDate == startDate.addingTimeInterval(56 * 60))
        #expect(engine.session.endsAt == endDate)
        #expect(engine.session.nextMicroReminderAt == startDate.addingTimeInterval(31 * 60))
    }

    @Test
    func restoredMeetingPauseDoesNotShowOverdueBreakOnLaunch() throws {
        var engine = SessionEngine(configuration: configuration, now: startDate)
        let meetingStart = startDate.addingTimeInterval(44 * 60)
        engine.beginMeetingPause(at: meetingStart)
        let savedState = try JSONDecoder().decode(
            SessionState.self,
            from: JSONEncoder().encode(engine.state)
        )
        var restored = SessionEngine(configuration: configuration, restoredState: savedState)
        let launchDate = meetingStart.addingTimeInterval(20 * 60)

        restored.prepareForLaunch(at: launchDate)
        #expect(restored.process(at: launchDate).isEmpty)
        restored.endMeetingPause(at: launchDate)
        #expect(restored.session.phase == .focusing)
        #expect(restored.snapshot(at: launchDate).remaining == 120)
    }

    @Test
    func wakingAfterFocusDeadlineKeepsRemainingTimeAndDoesNotOpenBreak() {
        var engine = SessionEngine(configuration: configuration, now: startDate)
        let sleepAt = startDate.addingTimeInterval(44 * 60 + 50)
        let wakeAt = sleepAt.addingTimeInterval(8 * 60 * 60)

        engine.beginSystemPause(at: sleepAt)
        #expect(engine.nextEventDate == nil)
        #expect(engine.snapshot(at: wakeAt).remaining == 10)
        #expect(engine.process(at: wakeAt).isEmpty)

        engine.endSystemPause(at: wakeAt, meetingActive: false)
        #expect(engine.snapshot(at: wakeAt).remaining == 60)
        #expect(engine.process(at: wakeAt).isEmpty)
        #expect(engine.process(at: wakeAt.addingTimeInterval(40)) == [.breakApproaching])
        #expect(engine.process(at: wakeAt.addingTimeInterval(60)) == [.fullBreakDue])
    }

    @Test
    func repeatedSleepAndWakeNotificationsDoNotExtendTheSessionTwice() {
        var engine = SessionEngine(configuration: configuration, now: startDate)
        let sleepAt = startDate.addingTimeInterval(10 * 60)
        let wakeAt = sleepAt.addingTimeInterval(60 * 60)

        engine.beginSystemPause(at: sleepAt)
        engine.beginSystemPause(at: sleepAt.addingTimeInterval(60))
        engine.endSystemPause(at: wakeAt, meetingActive: false)
        let deadline = engine.session.endsAt
        engine.endSystemPause(at: wakeAt.addingTimeInterval(60), meetingActive: false)

        #expect(deadline == startDate.addingTimeInterval(105 * 60))
        #expect(engine.session.endsAt == deadline)
        #expect(engine.snapshot(at: wakeAt).remaining == 35 * 60)
    }

    @Test
    func reopeningAfterQuitPreservesWorkAlreadyDone() throws {
        var original = SessionEngine(configuration: configuration, now: startDate)
        let quitAt = startDate.addingTimeInterval(25 * 60)
        let reopenAt = quitAt.addingTimeInterval(3 * 60 * 60)
        original.beginSystemPause(at: quitAt)

        let saved = try JSONDecoder().decode(SessionState.self, from: JSONEncoder().encode(original.state))
        var restored = SessionEngine(configuration: configuration, restoredState: saved)
        restored.prepareForLaunch(at: reopenAt)
        restored.endSystemPause(at: reopenAt, meetingActive: false)

        #expect(restored.snapshot(at: reopenAt).remaining == 20 * 60)
        #expect(restored.process(at: reopenAt).isEmpty)
        #expect(restored.session.nextMicroReminderAt == reopenAt.addingTimeInterval(15 * 60))
    }

    @Test
    func sleepingDuringBreakKeepsBreakTimeForWhenMacWakes() {
        var engine = SessionEngine(configuration: configuration, now: startDate)
        let breakAt = startDate.addingTimeInterval(45 * 60)
        _ = engine.process(at: breakAt)
        let sleepAt = breakAt.addingTimeInterval(60)
        let wakeAt = sleepAt.addingTimeInterval(2 * 60 * 60)

        engine.beginSystemPause(at: sleepAt)
        engine.endSystemPause(at: wakeAt, meetingActive: false)

        #expect(engine.session.phase == .onBreak)
        #expect(engine.snapshot(at: wakeAt).remaining == 4 * 60)
        #expect(engine.process(at: wakeAt).isEmpty)
    }

    @Test
    func relaunchDuringBreakStartsQuietlyAfterResumingStoredPause() throws {
        var original = SessionEngine(configuration: configuration, now: startDate)
        let breakAt = startDate.addingTimeInterval(45 * 60)
        _ = original.process(at: breakAt)
        let quitAt = breakAt.addingTimeInterval(60)
        let relaunchAt = quitAt.addingTimeInterval(30 * 60)
        original.beginSystemPause(at: quitAt)

        let saved = try JSONDecoder().decode(SessionState.self, from: JSONEncoder().encode(original.state))
        var restored = SessionEngine(configuration: configuration, restoredState: saved)
        restored.endSystemPause(at: relaunchAt, meetingActive: false)
        restored.prepareForLaunch(at: relaunchAt)

        #expect(restored.session.phase == .focusing)
        #expect(restored.session.startedAt == relaunchAt)
        #expect(restored.process(at: relaunchAt).isEmpty)
    }

    @Test
    func reopeningDuringMeetingPreservesFrozenCountdown() throws {
        var original = SessionEngine(configuration: configuration, now: startDate)
        let meetingAt = startDate.addingTimeInterval(10 * 60)
        let closeAt = meetingAt.addingTimeInterval(5 * 60)
        let reopenAt = closeAt.addingTimeInterval(2 * 60 * 60)
        original.beginMeetingPause(at: meetingAt)
        original.beginSystemPause(at: closeAt)

        let saved = try JSONDecoder().decode(SessionState.self, from: JSONEncoder().encode(original.state))
        var restored = SessionEngine(configuration: configuration, restoredState: saved)
        restored.prepareForLaunch(at: reopenAt)
        restored.endSystemPause(at: reopenAt, meetingActive: true)

        #expect(restored.snapshot(at: reopenAt).remaining == 35 * 60)
        #expect(restored.process(at: reopenAt).isEmpty)
        restored.endMeetingPause(at: reopenAt.addingTimeInterval(10 * 60))
        #expect(restored.snapshot(at: reopenAt.addingTimeInterval(10 * 60)).remaining == 36 * 60)
    }

    @Test
    func reopeningAfterMeetingEndedDoesNotCountTimeWhileClosed() throws {
        var original = SessionEngine(configuration: configuration, now: startDate)
        let meetingAt = startDate.addingTimeInterval(10 * 60)
        let closeAt = meetingAt.addingTimeInterval(5 * 60)
        let reopenAt = closeAt.addingTimeInterval(2 * 60 * 60)
        original.beginMeetingPause(at: meetingAt)
        original.beginSystemPause(at: closeAt)

        let saved = try JSONDecoder().decode(SessionState.self, from: JSONEncoder().encode(original.state))
        var restored = SessionEngine(configuration: configuration, restoredState: saved)
        restored.endSystemPause(at: reopenAt, meetingActive: false)

        #expect(restored.meetingPauseStartedAt == nil)
        #expect(restored.snapshot(at: reopenAt).remaining == 36 * 60)
        #expect(restored.process(at: reopenAt).isEmpty)
    }

    @Test
    func postponingBreakSchedulesAnotherWarning() {
        var engine = SessionEngine(configuration: configuration, now: startDate)
        let warningAt = startDate.addingTimeInterval(44 * 60 + 40)
        _ = engine.process(at: warningAt)

        engine.postponeBreak(by: 5 * 60)

        #expect(engine.session.endsAt == startDate.addingTimeInterval(50 * 60))
        #expect(engine.nextEventDate == startDate.addingTimeInterval(49 * 60 + 40))
        #expect(engine.process(at: startDate.addingTimeInterval(49 * 60 + 40)) == [.breakApproaching])
    }

    @Test
    func oneMinutePostponementDoesNotImmediatelyRepeatWarning() {
        var engine = SessionEngine(configuration: configuration, now: startDate)
        _ = engine.process(at: startDate.addingTimeInterval(44 * 60 + 53))

        engine.postponeBreak(by: 60)

        #expect(engine.nextEventDate == startDate.addingTimeInterval(45 * 60 + 40))
    }

    @Test
    func restoredWarningIsNotShownAgain() {
        var original = SessionEngine(configuration: configuration, now: startDate)
        _ = original.process(at: startDate.addingTimeInterval(44 * 60 + 40))
        var restored = SessionEngine(configuration: configuration, restoredState: original.state)

        #expect(restored.process(at: startDate.addingTimeInterval(44 * 60 + 40)).isEmpty)
        #expect(restored.nextEventDate == startDate.addingTimeInterval(45 * 60))
    }

    @Test
    func launchAfterExpiredFocusStartsQuietlyWithANewFocusCycle() {
        var engine = SessionEngine(configuration: configuration, now: startDate)
        let launchDate = startDate.addingTimeInterval(60 * 60)

        engine.prepareForLaunch(at: launchDate)

        #expect(engine.process(at: launchDate).isEmpty)
        #expect(engine.session.phase == .focusing)
        #expect(engine.session.startedAt == launchDate)
        #expect(engine.session.endsAt == launchDate.addingTimeInterval(configuration.focusDuration))
    }

    @Test
    func launchDuringBreakStartsQuietlyWithANewFocusCycle() {
        var engine = SessionEngine(configuration: configuration, now: startDate)
        let breakStart = startDate.addingTimeInterval(configuration.focusDuration)
        _ = engine.process(at: breakStart)
        let launchDate = breakStart.addingTimeInterval(60)

        engine.prepareForLaunch(at: launchDate)

        #expect(engine.process(at: launchDate).isEmpty)
        #expect(engine.session.phase == .focusing)
        #expect(engine.session.startedAt == launchDate)
    }

    @Test
    func launchDuringFocusKeepsDeadlineWithoutShowingMissedReminders() {
        var engine = SessionEngine(configuration: configuration, now: startDate)
        let launchDate = startDate.addingTimeInterval(25 * 60)

        engine.prepareForLaunch(at: launchDate)

        #expect(engine.process(at: launchDate).isEmpty)
        #expect(engine.session.startedAt == startDate)
        #expect(engine.session.endsAt == startDate.addingTimeInterval(configuration.focusDuration))
        #expect(engine.session.nextMicroReminderAt == startDate.addingTimeInterval(40 * 60))
    }

    @Test
    func launchNearBreakWarningStartsANewFocusCycle() {
        var engine = SessionEngine(configuration: configuration, now: startDate)
        let launchDate = startDate.addingTimeInterval(44 * 60 + 45)

        engine.prepareForLaunch(at: launchDate)

        #expect(engine.process(at: launchDate).isEmpty)
        #expect(engine.session.startedAt == launchDate)
        #expect(engine.hasShownBreakWarning == false)
    }

    @Test
    func fullBreakTakesPriorityOverMissedMicroReminders() {
        var engine = SessionEngine(configuration: configuration, now: startDate)
        let wakeDate = startDate.addingTimeInterval(60 * 60)

        let events = engine.process(at: wakeDate)

        #expect(events == [.fullBreakDue])
        #expect(engine.session.phase == .onBreak)
        #expect(engine.session.startedAt == wakeDate)
    }

    @Test
    func startsANewFocusCycleWhenBreakEnds() {
        var engine = SessionEngine(configuration: configuration, now: startDate)
        let breakStart = startDate.addingTimeInterval(45 * 60)
        _ = engine.process(at: breakStart)
        let breakEnd = breakStart.addingTimeInterval(5 * 60)

        let events = engine.process(at: breakEnd)

        #expect(events == [.breakEnded])
        #expect(engine.session.phase == .focusing)
        #expect(engine.session.startedAt == breakEnd)
        #expect(engine.session.endsAt == breakEnd.addingTimeInterval(45 * 60))
    }

    @Test
    func snoozeExtendsOnlyTheCurrentFocusDeadline() {
        var engine = SessionEngine(configuration: configuration, now: startDate)

        engine.snooze()

        #expect(engine.session.endsAt == startDate.addingTimeInterval(50 * 60))
        #expect(engine.session.nextMicroReminderAt == startDate.addingTimeInterval(20 * 60))
    }

    @Test
    func configurationChangesApplyToTheNextFocusCycle() {
        var engine = SessionEngine(configuration: configuration, now: startDate)
        let originalDeadline = engine.session.endsAt
        let updatedConfiguration = FocusConfiguration(
            focusDuration: 60 * 60,
            microReminderInterval: 15 * 60,
            breakDuration: 10 * 60,
            snoozeDuration: 10 * 60
        )

        engine.updateConfiguration(updatedConfiguration, at: startDate)
        engine.startBreak(at: startDate)
        engine.completeBreak(at: startDate.addingTimeInterval(10 * 60))

        #expect(originalDeadline == startDate.addingTimeInterval(45 * 60))
        #expect(engine.session.endsAt == startDate.addingTimeInterval(70 * 60))
        #expect(engine.session.nextMicroReminderAt == startDate.addingTimeInterval(25 * 60))
    }

    @Test
    func changingFocusDurationRestartsCurrentCycleAndSurvivesRestore() {
        var engine = SessionEngine(configuration: configuration, now: startDate)
        engine.snooze()
        var updatedConfiguration = configuration
        updatedConfiguration.focusDuration = 30 * 60
        let changeDate = startDate.addingTimeInterval(10 * 60)

        engine.updateConfiguration(updatedConfiguration, at: changeDate)

        #expect(engine.session.startedAt == changeDate)
        #expect(engine.session.endsAt == changeDate.addingTimeInterval(30 * 60))
        #expect(engine.activeConfiguration.focusDuration == 30 * 60)
        let restored = SessionEngine(configuration: updatedConfiguration, restoredState: engine.state)
        #expect(restored.session.endsAt == changeDate.addingTimeInterval(30 * 60))
    }

    @Test
    func shorterFocusDurationDoesNotStartBreakImmediately() {
        var engine = SessionEngine(configuration: configuration, now: startDate)
        var updatedConfiguration = configuration
        updatedConfiguration.focusDuration = 10 * 60
        let changeDate = startDate.addingTimeInterval(10 * 60)

        engine.updateConfiguration(updatedConfiguration, at: changeDate)

        #expect(engine.process(at: changeDate).isEmpty)
        #expect(engine.session.phase == .focusing)
        #expect(engine.session.endsAt == changeDate.addingTimeInterval(10 * 60))
    }

    @Test
    func configurationChangesDoNotAlterTheCurrentCycle() {
        var engine = SessionEngine(configuration: configuration, now: startDate)
        let updatedConfiguration = FocusConfiguration(
            focusDuration: 45 * 60,
            microReminderInterval: 15 * 60,
            breakDuration: 10 * 60,
            snoozeDuration: 10 * 60
        )

        engine.updateConfiguration(updatedConfiguration)
        let events = engine.process(at: startDate.addingTimeInterval(20 * 60))
        engine.snooze()

        #expect(events == [.microReminderDue])
        #expect(engine.session.nextMicroReminderAt == startDate.addingTimeInterval(40 * 60))
        #expect(engine.session.endsAt == startDate.addingTimeInterval(50 * 60))
    }

    @Test
    func restoredStateKeepsTheActiveCycleConfiguration() {
        var original = SessionEngine(configuration: configuration, now: startDate)
        let updatedConfiguration = FocusConfiguration(
            focusDuration: 60 * 60,
            microReminderInterval: 15 * 60,
            breakDuration: 10 * 60,
            snoozeDuration: 10 * 60
        )
        original.updateConfiguration(updatedConfiguration, at: startDate)

        var restored = SessionEngine(
            configuration: updatedConfiguration,
            restoredState: original.state
        )
        _ = restored.process(at: startDate.addingTimeInterval(20 * 60))

        #expect(restored.session.nextMicroReminderAt == startDate.addingTimeInterval(40 * 60))
    }

    @Test
    func snapshotCalculatesRemainingTimeAndProgress() {
        let engine = SessionEngine(configuration: configuration, now: startDate)

        let snapshot = engine.snapshot(at: startDate.addingTimeInterval(15 * 60))

        #expect(snapshot.remaining == 30 * 60)
        #expect(snapshot.progress == 1.0 / 3.0)
    }

    @Test
    func snoozeBreakPostponesBreakAndStartsFocusForSnoozeDuration() {
        var engine = SessionEngine(configuration: configuration, now: startDate)
        let breakStart = startDate.addingTimeInterval(45 * 60)
        _ = engine.process(at: breakStart)

        #expect(engine.session.phase == .onBreak)

        engine.snoozeBreak(at: breakStart)

        #expect(engine.session.phase == .focusing)
        #expect(engine.session.startedAt == breakStart)
        #expect(engine.session.endsAt == breakStart.addingTimeInterval(5 * 60))
    }

    @Test
    func completeBreakDirectlySkipsBreakAndStartsFullFocusDuration() {
        var engine = SessionEngine(configuration: configuration, now: startDate)
        let breakStart = startDate.addingTimeInterval(45 * 60)
        _ = engine.process(at: breakStart)

        #expect(engine.session.phase == .onBreak)

        engine.completeBreak(at: breakStart)

        #expect(engine.session.phase == .focusing)
        #expect(engine.session.startedAt == breakStart)
        #expect(engine.session.endsAt == breakStart.addingTimeInterval(configuration.focusDuration))
    }

    @Test
    func suggestsBreakAfterThreeConsecutiveSkipsAndResetsAfterTakingABreak() {
        var engine = SessionEngine(configuration: configuration, now: startDate)

        #expect(engine.skipBreak(at: startDate) == false)
        #expect(engine.skipBreak(at: startDate.addingTimeInterval(1)) == false)
        #expect(engine.skipBreak(at: startDate.addingTimeInterval(2)) == true)
        #expect(engine.consecutiveSkippedBreaks == 3)

        let restored = SessionEngine(configuration: configuration, restoredState: engine.state)
        #expect(restored.consecutiveSkippedBreaks == 3)

        let breakStart = engine.session.endsAt
        #expect(engine.process(at: breakStart) == [.fullBreakDue])
        #expect(engine.process(at: engine.session.endsAt) == [.breakEnded])
        #expect(engine.consecutiveSkippedBreaks == 0)
        #expect(engine.skipBreak(at: engine.session.startedAt) == false)
    }

    @Test
    func skippingAnActiveBreakDoesNotCountAsTakingIt() {
        var engine = SessionEngine(configuration: configuration, now: startDate)
        let breakStart = engine.session.endsAt
        _ = engine.process(at: breakStart)

        #expect(engine.skipBreak(at: breakStart) == false)
        #expect(engine.breaksTakenToday(at: breakStart) == 0)
        #expect(engine.consecutiveSkippedBreaks == 1)
    }

    @Test
    func endingABreakAfterTwoMinutesDoesNotSuggestAnotherBreak() {
        var engine = SessionEngine(configuration: configuration, now: startDate)
        _ = engine.skipBreak(at: startDate)
        _ = engine.skipBreak(at: startDate.addingTimeInterval(1))
        let breakStart = engine.session.endsAt
        _ = engine.process(at: breakStart)

        #expect(engine.skipBreak(at: breakStart.addingTimeInterval(2 * 60)) == false)
        #expect(engine.consecutiveSkippedBreaks == 0)
        #expect(engine.breaksTakenToday(at: breakStart.addingTimeInterval(2 * 60)) == 0)
        #expect(engine.skipBreak(at: engine.session.startedAt) == false)
    }

    @Test
    func endingABreakImmediatelyStillCountsAsSkippingIt() {
        var engine = SessionEngine(configuration: configuration, now: startDate)
        _ = engine.skipBreak(at: startDate)
        _ = engine.skipBreak(at: startDate.addingTimeInterval(1))
        let breakStart = engine.session.endsAt
        _ = engine.process(at: breakStart)

        #expect(engine.skipBreak(at: breakStart.addingTimeInterval(30)) == true)
        #expect(engine.consecutiveSkippedBreaks == 3)
    }

    @Test
    func completedBreakCountPersistsAndResetsOnTheNextDay() {
        var engine = SessionEngine(configuration: configuration, now: startDate)
        let breakStart = startDate.addingTimeInterval(configuration.focusDuration)

        _ = engine.process(at: breakStart)
        #expect(engine.breaksTakenToday(at: breakStart) == 0)

        engine.completeBreak(at: breakStart.addingTimeInterval(60))
        #expect(engine.breaksTakenToday(at: breakStart.addingTimeInterval(60)) == 1)

        let restored = SessionEngine(configuration: configuration, restoredState: engine.state)
        #expect(restored.breaksTakenToday(at: breakStart.addingTimeInterval(60)) == 1)
        #expect(restored.breaksTakenToday(at: breakStart.addingTimeInterval(24 * 60 * 60)) == 0)
    }

}
