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
    func warnsOneMinuteBeforeBreakOnlyOnce() {
        var engine = SessionEngine(configuration: configuration, now: startDate)
        let warningAt = startDate.addingTimeInterval(44 * 60)

        #expect(engine.nextEventDate == startDate.addingTimeInterval(20 * 60))
        _ = engine.process(at: startDate.addingTimeInterval(20 * 60))
        _ = engine.process(at: startDate.addingTimeInterval(40 * 60))
        #expect(engine.nextEventDate == warningAt)
        #expect(engine.process(at: warningAt) == [.breakApproaching])
        #expect(engine.process(at: warningAt).isEmpty)
        #expect(engine.nextEventDate == startDate.addingTimeInterval(45 * 60))
    }

    @Test
    func postponingBreakSchedulesAnotherWarning() {
        var engine = SessionEngine(configuration: configuration, now: startDate)
        let warningAt = startDate.addingTimeInterval(44 * 60)
        _ = engine.process(at: warningAt)

        engine.postponeBreak(by: 5 * 60)

        #expect(engine.session.endsAt == startDate.addingTimeInterval(50 * 60))
        #expect(engine.nextEventDate == startDate.addingTimeInterval(49 * 60))
        #expect(engine.process(at: startDate.addingTimeInterval(49 * 60)) == [.breakApproaching])
    }

    @Test
    func oneMinutePostponementDoesNotImmediatelyRepeatWarning() {
        var engine = SessionEngine(configuration: configuration, now: startDate)
        _ = engine.process(at: startDate.addingTimeInterval(44 * 60 + 53))

        engine.postponeBreak(by: 60)

        #expect(engine.nextEventDate == startDate.addingTimeInterval(46 * 60))
    }

    @Test
    func restoredWarningIsNotShownAgain() {
        var original = SessionEngine(configuration: configuration, now: startDate)
        _ = original.process(at: startDate.addingTimeInterval(44 * 60))
        var restored = SessionEngine(configuration: configuration, restoredState: original.state)

        #expect(restored.process(at: startDate.addingTimeInterval(44 * 60)).isEmpty)
        #expect(restored.nextEventDate == startDate.addingTimeInterval(45 * 60))
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

        engine.updateConfiguration(updatedConfiguration)
        engine.startBreak(at: startDate)
        engine.completeBreak(at: startDate.addingTimeInterval(10 * 60))

        #expect(originalDeadline == startDate.addingTimeInterval(45 * 60))
        #expect(engine.session.endsAt == startDate.addingTimeInterval(70 * 60))
        #expect(engine.session.nextMicroReminderAt == startDate.addingTimeInterval(25 * 60))
    }

    @Test
    func configurationChangesDoNotAlterTheCurrentCycle() {
        var engine = SessionEngine(configuration: configuration, now: startDate)
        let updatedConfiguration = FocusConfiguration(
            focusDuration: 60 * 60,
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
        original.updateConfiguration(updatedConfiguration)

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
}
