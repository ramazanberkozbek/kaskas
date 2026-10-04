import Foundation
import Testing
@testable import Kaskas

struct SessionLifecycleTests {
    private let startDate = Date(timeIntervalSinceReferenceDate: 1_000_000)
    private let configuration = FocusConfiguration(
        focusDuration: 25 * 60,
        microReminderInterval: 10 * 60,
        breakDuration: 5 * 60,
        longBreakDuration: 15 * 60,
        snoozeDuration: 5 * 60
    )

    // MARK: - Characterization Tests (R1, R7, R8, R9, R10 - Existing Desired Invariants)

    @Test
    func shortSleepPreservesRemainingFocusTime() {
        // R1: Focus + short sleep (< breakDuration) preserves remaining time
        var engine = SessionEngine(configuration: configuration, now: startDate)
        let sleepStart = startDate.addingTimeInterval(10 * 60)
        let wakeTime = sleepStart.addingTimeInterval(2 * 60) // 2 min sleep (< 5 min breakDuration)

        engine.send(.sleep, at: sleepStart)
        engine.send(.systemResumed(meetingActive: false), at: wakeTime)

        let snapshot = engine.snapshot(at: wakeTime)
        #expect(snapshot.phase == .focusing)
        // 10 minutes elapsed before sleep, so 15 minutes should remain
        #expect(abs(snapshot.remaining - 15 * 60) < 1.0)
    }

    @Test
    func manualPauseIsPreservedAcrossSleepRegardlessOfDuration() {
        // R8: Manual pause is explicitly initiated by the user and must NOT be auto-reset
        var engine = SessionEngine(configuration: configuration, now: startDate)
        let pauseTime = startDate.addingTimeInterval(10 * 60)
        engine.send(.setManualPause(active: true), at: pauseTime)

        // Mac sleeps for 8 hours while manually paused
        let sleepTime = pauseTime.addingTimeInterval(60)
        let wakeTime = sleepTime.addingTimeInterval(8 * 3600)

        engine.send(.sleep, at: sleepTime)
        engine.send(.systemResumed(meetingActive: false), at: wakeTime)

        #expect(engine.manualPauseStartedAt != nil)
        let snapshot = engine.snapshot(at: wakeTime)
        // Remaining time still preserved (15 minutes remaining)
        #expect(abs(snapshot.remaining - 15 * 60) < 1.0)

        // Resuming manual pause starts right where it left off
        engine.send(.setManualPause(active: false), at: wakeTime)
        let resumedSnapshot = engine.snapshot(at: wakeTime)
        #expect(resumedSnapshot.manualPauseStartedAt == nil)
        #expect(resumedSnapshot.phase == .focusing)
        #expect(abs(resumedSnapshot.remaining - 15 * 60) < 1.0)
    }

    @Test
    func meetingPauseSurvivesSleepAndResumesIfMeetingStillActive() {
        // R9: Meeting + sleep -> resumes meeting if still active
        var engine = SessionEngine(configuration: configuration, now: startDate)
        let meetingStart = startDate.addingTimeInterval(5 * 60)
        engine.send(.setMeeting(active: true), at: meetingStart)

        let sleepTime = meetingStart.addingTimeInterval(5 * 60)
        let wakeTime = sleepTime.addingTimeInterval(30 * 60)

        engine.send(.sleep, at: sleepTime)
        let effects = engine.send(.systemResumed(meetingActive: true), at: wakeTime)

        #expect(engine.meetingPauseStartedAt != nil)
        let snapshot = engine.snapshot(at: wakeTime)
        #expect(snapshot.meetingPauseStartedAt != nil)

        // Assert returned effects: NO fake break end sound, NO fake break record, completedBreaks unchanged
        #expect(!effects.contains(.playBreakEndSound))
        #expect(!effects.contains {
            if case .persistSession(let record, _) = $0 { return record != nil }
            return false
        })
        #expect(engine.breaksTakenToday(at: wakeTime) == 0)
    }

    @Test
    func midnightRolloverResetsDailyCountersWithoutStoppingActiveFocus() {
        // R10: Midnight crossing resets completed breaks count for the day
        var engine = SessionEngine(configuration: configuration, now: startDate)
        engine.send(.startBreakNow, at: startDate)
        engine.send(.completeBreak, at: startDate)
        #expect(engine.breaksTakenToday(at: startDate) == 1)

        // Next day (24h later)
        let nextDay = startDate.addingTimeInterval(24 * 3600)
        #expect(engine.breaksTakenToday(at: nextDay) == 0)
    }

    // MARK: - Lifecycle Invariant Tests (R2, R4, R5, R6 - Target behaviors unlocked in Phase 3)

    @Test
    func naturalBreakThresholdResetsFocusAfterLongAway() {
        // R2: When away for >= breakDuration (5 mins), focus should NOT resume where left off.
        // It should count natural break as taken and start a fresh focus session on return.
        var engine = SessionEngine(configuration: configuration, now: startDate)
        let sleepStart = startDate.addingTimeInterval(10 * 60)
        let wakeTime = sleepStart.addingTimeInterval(10 * 60) // 10 min sleep (>= 5 min breakDuration)

        engine.send(.sleep, at: sleepStart)
        engine.send(.systemResumed(meetingActive: false), at: wakeTime)

        let snapshot = engine.snapshot(at: wakeTime)
        #expect(snapshot.remaining == 25 * 60)
        #expect(snapshot.startedAt == wakeTime)
    }

    @Test(arguments: [SystemCause.sleep, .lock, .quit])
    func completedAwayBreakIsRecordedWithoutReplayingSounds(cause: SystemCause) {
        for wasOnBreak in [false, true] {
            var engine = SessionEngine(configuration: configuration, now: startDate)
            if wasOnBreak {
                engine.send(.startBreakNow, at: startDate)
            }
            let awayStart = startDate.addingTimeInterval(60)
            let returnedAt = awayStart.addingTimeInterval(3600)
            engine.send(.systemSuspended(cause: cause), at: awayStart)

            let effects = engine.send(
                cause == .quit ? .launch : .systemResumed,
                at: returnedAt
            )

            #expect(!effects.contains(.playBreakStartSound))
            #expect(!effects.contains(.playBreakEndSound))
            #expect(engine.session.phase == .focusing)
            #expect(engine.breaksTakenToday(at: returnedAt) == 1)
            #expect(effects.contains {
                if case .persistSession(let record, _) = $0 { return record != nil }
                return false
            })
        }
    }

    @Test
    func unfinishedBreakResumesSilentlyAndSoundsWhenItEndsWhileAwake() {
        var engine = SessionEngine(configuration: configuration, now: startDate)
        engine.send(.startBreakNow, at: startDate)
        engine.send(.sleep, at: startDate.addingTimeInterval(60))
        let returnedAt = startDate.addingTimeInterval(120)
        let effects = engine.send(.systemResumed, at: returnedAt)

        #expect(engine.session.phase == .onBreak)
        #expect(!effects.contains(.playBreakStartSound))
        #expect(!effects.contains(.playBreakEndSound))
        #expect(effects.contains(.showBreak(endsAt: engine.session.endsAt)))
        let endEffects = engine.send(.tick, at: engine.session.endsAt)
        #expect(endEffects.contains(.playBreakEndSound))
    }

    @Test
    @MainActor
    func lockDuringBreakSuspendsUntilUnlock() {
        // R4: If screen locks during break, break shouldn't expire silently into a studying session while locked
        let suiteName = "LockBreakTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let start = Date()
        let store = SessionStore(defaults: defaults)
        let controller = SessionController(store: store, now: start)
        controller.start()
        controller.startBreakNow()

        #expect(controller.sessionSnapshot.phase == .onBreak)

        // User locks screen 1 minute into break
        let lockTime = start.addingTimeInterval(60)
        controller.screenOrSessionDidLock(at: lockTime)

        let pastBreakTime = start.addingTimeInterval(10 * 60)
        controller.reconcile(at: pastBreakTime)
        #expect(controller.sessionSnapshot.phase != .focusing)
    }

    @Test
    func sleepDuringBreakLongerThanRemainingCompletesBreak() {
        // R5: If Mac sleeps during a break for longer than remaining break duration,
        // break should be considered completed on wake, starting fresh focus.
        var engine = SessionEngine(configuration: configuration, now: startDate)
        engine.send(.startBreakNow, at: startDate)
        #expect(engine.session.phase == .onBreak)

        let sleepStart = startDate.addingTimeInterval(60) // 4 min break left
        let wakeTime = sleepStart.addingTimeInterval(60 * 60) // 1 hour sleep

        engine.send(.sleep, at: sleepStart)
        engine.send(.systemResumed(meetingActive: false), at: wakeTime)

        let snapshot = engine.snapshot(at: wakeTime)
        #expect(snapshot.phase == .focusing)
    }

    @Test
    func idleFollowedBySleepMeasuresAwayDurationFromIdleStart() {
        // R6: User idle at T, sleep at T+5m, wake at T+20m.
        // Away duration should be measured from idle start (20m total >= 5m breakDuration)
        var engine = SessionEngine(configuration: configuration, now: startDate)
        let idleStart = startDate.addingTimeInterval(10 * 60)
        engine.send(.beginIdle(startedAt: idleStart), at: idleStart)

        let sleepStart = idleStart.addingTimeInterval(5 * 60)
        engine.send(.sleep, at: sleepStart)

        let wakeTime = sleepStart.addingTimeInterval(15 * 60)
        engine.send(.systemResumed(meetingActive: false), at: wakeTime)

        let snapshot = engine.snapshot(at: wakeTime)
        #expect(snapshot.remaining == 25 * 60) // Fresh cycle
    }

    // MARK: - Phase 4 Tests: Effect Ordering & Meeting Reentrancy

    @Test
    func effectOrderingStrictlyFollowsDismissShowSoundPersistSchedule() {
        // Test 1: Full break due on tick
        var engine = SessionEngine(configuration: configuration, now: startDate)
        let breakDueDate = startDate.addingTimeInterval(25 * 60)
        let breakEffects = engine.send(.tick, at: breakDueDate)

        // Verify ranks are non-decreasing (dismiss: 10, show: 20, sound: 30, persist: 40, schedule: 50)
        let ranks = breakEffects.map(\.categoryRank)
        #expect(ranks == ranks.sorted())
        #expect(breakEffects == [
            .dismissMicroReminder,
            .dismissBreakWarning,
            .showBreak(endsAt: breakDueDate.addingTimeInterval(5 * 60)),
            .playBreakStartSound,
            .persistSession(record: nil, activityKind: .breakTime),
            .scheduleNextTick(at: breakDueDate.addingTimeInterval(5 * 60))
        ])

        // Test 2: Break ends on tick
        let breakEndDate = breakDueDate.addingTimeInterval(5 * 60)
        let endEffects = engine.send(.tick, at: breakEndDate)
        let endRanks = endEffects.map(\.categoryRank)
        #expect(endRanks == endRanks.sorted())
        #expect(endEffects.first == .dismissBreak)
        #expect(endEffects.contains(.playBreakEndSound))
        #expect(endEffects.last == .scheduleNextTick(at: breakEndDate.addingTimeInterval(10 * 60))) // micro reminder

        // Test 3: Start break now
        var freshEngine = SessionEngine(configuration: configuration, now: startDate)
        let startNowEffects = freshEngine.send(.startBreakNow, at: startDate.addingTimeInterval(60))
        let startNowRanks = startNowEffects.map(\.categoryRank)
        #expect(startNowRanks == startNowRanks.sorted())
        #expect(startNowEffects.contains(.showBreak(endsAt: startDate.addingTimeInterval(60 + 5 * 60))))
        #expect(startNowEffects.contains(.playBreakStartSound))

        // Test 4: System sleep
        let sleepEffects = freshEngine.send(.sleep, at: startDate.addingTimeInterval(120))
        let sleepRanks = sleepEffects.map(\.categoryRank)
        #expect(sleepRanks == sleepRanks.sorted())
        #expect(sleepEffects.contains(.cancelScheduler))
    }

    @Test
    func meetingCallbackReentrancyAndIdempotence() {
        var engine = SessionEngine(configuration: configuration, now: startDate)
        let meetingTime = startDate.addingTimeInterval(5 * 60)

        // 1. Initial meeting pause returns dismissals + persist + cancel
        let pauseEffects = engine.send(.setMeeting(active: true), at: meetingTime)
        #expect(!pauseEffects.isEmpty)
        #expect(engine.status.isMeetingPaused)

        // 2. Duplicate active callback (reentrancy / duplicate monitor trigger) is a complete no-op
        let duplicateActiveEffects = engine.send(.setMeeting(active: true), at: meetingTime.addingTimeInterval(2))
        #expect(duplicateActiveEffects.isEmpty)
        #expect(engine.status.isMeetingPaused)

        // 3. Meeting ends: resumes with grace delay (60s)
        let resumeTime = meetingTime.addingTimeInterval(10 * 60)
        let resumeEffects = engine.send(.setMeeting(active: false), at: resumeTime)
        #expect(!resumeEffects.isEmpty)
        #expect(!engine.status.isMeetingPaused)

        // 4. Duplicate inactive callback is a complete no-op
        let duplicateInactiveEffects = engine.send(.setMeeting(active: false), at: resumeTime.addingTimeInterval(2))
        #expect(duplicateInactiveEffects.isEmpty)
        #expect(!engine.status.isMeetingPaused)

        // 5. Meeting callback during break: meetings only pause focus sessions, not breaks
        engine.send(.startBreakNow, at: resumeTime.addingTimeInterval(10))
        #expect(engine.status.phase == .onBreak)
        let breakMeetingEffects = engine.send(.setMeeting(active: true), at: resumeTime.addingTimeInterval(20))
        #expect(breakMeetingEffects.isEmpty)
        #expect(engine.status.phase == .onBreak)
        #expect(!engine.status.isMeetingPaused)
    }

    @Test
    func meetingSleepWakeWhenMeetingEndedAboveBreakThresholdCountsNaturalBreakAndStartsFreshFocus() {
        var engine = SessionEngine(configuration: configuration, now: startDate)
        let meetingStart = startDate.addingTimeInterval(5 * 60)
        engine.send(.setMeeting(active: true), at: meetingStart)

        let sleepTime = meetingStart.addingTimeInterval(5 * 60)
        let wakeTime = sleepTime.addingTimeInterval(30 * 60)

        engine.send(.sleep, at: sleepTime)
        let effects = engine.send(.systemResumed(meetingActive: false), at: wakeTime)

        #expect(!effects.contains(.playBreakEndSound))
        #expect(effects.contains {
            if case .persistSession(let record, let kind) = $0 {
                return record != nil && kind == .studying
            }
            return false
        })
        #expect(engine.breaksTakenToday(at: wakeTime) == 1)
        #expect(!engine.status.isMeetingPaused)
        #expect(engine.session.phase == .focusing)
        #expect(engine.snapshot(at: wakeTime).remaining == configuration.focusDuration)
    }

    @Test
    func meetingSleepWakeWhenMeetingEndedBelowBreakThresholdResumesFocusWithGraceWithoutBreak() {
        var engine = SessionEngine(configuration: configuration, now: startDate)
        let meetingStart = startDate.addingTimeInterval(5 * 60)
        engine.send(.setMeeting(active: true), at: meetingStart)

        let sleepTime = meetingStart.addingTimeInterval(60)
        let wakeTime = sleepTime.addingTimeInterval(2 * 60)

        engine.send(.sleep, at: sleepTime)
        let effects = engine.send(.systemResumed(meetingActive: false), at: wakeTime)

        #expect(!effects.contains(.playBreakEndSound))
        #expect(!effects.contains {
            if case .persistSession(let record, _) = $0 { return record != nil }
            return false
        })
        #expect(engine.breaksTakenToday(at: wakeTime) == 0)
        #expect(!engine.status.isMeetingPaused)
        #expect(engine.session.phase == .focusing)
        #expect(engine.snapshot(at: wakeTime).remaining == 21 * 60)
    }

    @Test
    func manualPauseAndIdlePauseAreAbsoluteAgainstMeetingDetection() {
        // 1. Manual pause is absolute
        var engine = SessionEngine(configuration: configuration, now: startDate)
        let pauseTime = startDate.addingTimeInterval(5 * 60)
        engine.send(.setManualPause(active: true), at: pauseTime)
        #expect(engine.status.isManualPaused)
        #expect(engine.status.activityKind == .kaskasPaused)

        // Meeting detected while manually paused -> complete no-op
        let meetingEffects = engine.send(.setMeeting(active: true), at: pauseTime.addingTimeInterval(60))
        #expect(meetingEffects.isEmpty)
        #expect(engine.status.isManualPaused)
        #expect(!engine.status.isMeetingPaused)
        #expect(engine.status.activityKind == .kaskasPaused)

        // Meeting ends while manually paused -> complete no-op
        let endMeetingEffects = engine.send(.setMeeting(active: false), at: pauseTime.addingTimeInterval(120))
        #expect(endMeetingEffects.isEmpty)
        #expect(engine.status.isManualPaused)
        #expect(engine.status.activityKind == .kaskasPaused)

        // 2. Idle pause is absolute against meeting
        var idleEngine = SessionEngine(configuration: configuration, now: startDate)
        let idleTime = startDate.addingTimeInterval(5 * 60)
        idleEngine.send(.beginIdle(startedAt: idleTime), at: idleTime)
        #expect(idleEngine.status.isIdlePaused)
        #expect(idleEngine.status.activityKind == .computerInactive)

        let idleMeetingEffects = idleEngine.send(.setMeeting(active: true), at: idleTime.addingTimeInterval(60))
        #expect(idleMeetingEffects.isEmpty)
        #expect(idleEngine.status.isIdlePaused)
        #expect(!idleEngine.status.isMeetingPaused)
        #expect(idleEngine.status.activityKind == .computerInactive)
    }

    @Test
    func naturalBreakDuringSleepIsSessionBoundaryInStudySessionGrouping() throws {
        var engine = SessionEngine(configuration: configuration, now: startDate)
        let sleepStart = startDate.addingTimeInterval(10 * 60)
        let wakeTime = sleepStart.addingTimeInterval(10 * 60) // 10m sleep >= 5m breakDuration

        engine.send(.sleep, at: sleepStart)
        let effects = engine.send(.systemResumed(meetingActive: false), at: wakeTime)

        var naturalRecord: BreakHistoryEntry?
        for effect in effects {
            if case .persistSession(let record, _) = effect, let record {
                naturalRecord = record
            }
        }

        let record = try #require(naturalRecord)
        #expect(record.isSessionBoundary)
        #expect(record.startedAt == sleepStart)
        #expect(record.outcome == .completed)
        #expect(record.source == .scheduled)

        // Grouping: first interval ends at sleepStart, second interval starts at wakeTime
        let first = ActivityInterval(kind: .studying, startedAt: startDate, endedAt: sleepStart)
        let second = ActivityInterval(kind: .studying, startedAt: wakeTime, endedAt: wakeTime.addingTimeInterval(10 * 60))
        let sessions = StudySessionGrouping.group([first, second], breakEntries: [record])
        #expect(sessions.count == 2)
        #expect(sessions[0].endedAt == sleepStart)
        #expect(sessions[1].startedAt == wakeTime)
    }

    @Test
    func startBreakNowDismissesMicroReminder() {
        var engine = SessionEngine(configuration: configuration, now: startDate)
        let microReminderTime = startDate.addingTimeInterval(10 * 60)
        let tickEffects = engine.send(.tick, at: microReminderTime)
        #expect(tickEffects.contains(.showMicroReminder))

        // When starting break now, open micro-reminder must be dismissed
        let breakEffects = engine.send(.startBreakNow, at: microReminderTime.addingTimeInterval(5))
        #expect(breakEffects.contains(.dismissMicroReminder))
        #expect(breakEffects.contains(.dismissBreakWarning))
        #expect(breakEffects.contains(.dismissSkippedBreakReminder))
        #expect(breakEffects.contains(.showBreak(endsAt: microReminderTime.addingTimeInterval(5 + 5 * 60))))
    }

    @Test
    func snoozeActionIsExcludedDuringMeetingPause() {
        var engine = SessionEngine(configuration: configuration, now: startDate)
        let meetingTime = startDate.addingTimeInterval(5 * 60)
        engine.send(.setMeeting(active: true), at: meetingTime)

        let snapshot = engine.snapshot(at: meetingTime)
        #expect(snapshot.phase == .focusing)
        #expect(snapshot.status.isMeetingPaused)

        // Snooze directly on engine during meeting pause is a complete no-op
        let snoozeEffects = engine.send(.snooze, at: meetingTime.addingTimeInterval(10))
        #expect(engine.status.isMeetingPaused)
        #expect(snoozeEffects.contains(.cancelScheduler))
    }

    @Test
    func idleMeetingDetectionPreservesIdleStateAndTransitionsToMeetingPauseOnReturn() {
        // 1. Enter idle
        var engine = SessionEngine(configuration: configuration, now: startDate)
        let idleStart = startDate.addingTimeInterval(5 * 60)
        engine.send(.beginIdle(startedAt: idleStart), at: idleStart)
        #expect(engine.status.isIdlePaused)
        #expect(!engine.status.isMeetingPaused)
        #expect(engine.status.activityKind == .computerInactive)

        // 2. Meeting starts during idle: must NOT override state to .meeting, but records meetingPending
        let meetingStart = idleStart.addingTimeInterval(60)
        let meetingEffects = engine.send(.setMeeting(active: true), at: meetingStart)
        #expect(meetingEffects.isEmpty)
        #expect(engine.status.isIdlePaused)
        #expect(!engine.status.isMeetingPaused)
        #expect(engine.status.activityKind == .computerInactive)

        // 3. User returns from short idle (< breakDuration, e.g. 2 min total) while meeting is STILL active:
        // Focus must NOT start! It transitions immediately to meeting pause.
        let shortReturnTime = idleStart.addingTimeInterval(2 * 60)
        let returnEffects = engine.send(.idleReturned(returnedAt: shortReturnTime), at: shortReturnTime)
        #expect(!returnEffects.contains(.playBreakEndSound))
        #expect(returnEffects.contains(.cancelScheduler))
        #expect(engine.status.isMeetingPaused)
        #expect(!engine.status.isIdlePaused)
        #expect(engine.status.activityKind == .meeting)
        #expect(engine.status.isPaused)

        // 4. When meeting ends, focus resumes with grace delay
        let meetingEndTime = shortReturnTime.addingTimeInterval(10 * 60)
        let endMeetingEffects = engine.send(.setMeeting(active: false), at: meetingEndTime)
        #expect(!endMeetingEffects.isEmpty)
        #expect(!engine.status.isMeetingPaused)
        #expect(engine.status.activityKind == .studying)
        #expect(!engine.status.isPaused)
    }

    @Test
    func longIdleWithMeetingActiveRecordsBreakAndTransitionsToMeetingPauseWithoutStartingFocus() {
        var engine = SessionEngine(configuration: configuration, now: startDate)
        let idleStart = startDate.addingTimeInterval(5 * 60)
        engine.send(.beginIdle(startedAt: idleStart), at: idleStart)

        let meetingStart = idleStart.addingTimeInterval(2 * 60)
        _ = engine.send(.setMeeting(active: true), at: meetingStart)

        // 10m away >= 5m breakDuration: natural idle break recorded
        let longReturnTime = idleStart.addingTimeInterval(10 * 60)
        let returnEffects = engine.send(.idleReturned(returnedAt: longReturnTime), at: longReturnTime)

        // Break recorded, but meeting is active so kind is .meeting and no sound played
        #expect(!returnEffects.contains(.playBreakEndSound))
        #expect(returnEffects.contains {
            if case .persistSession(let record, let kind) = $0 {
                return record != nil && kind == .meeting
            }
            return false
        })
        #expect(engine.breaksTakenToday(at: longReturnTime) == 1)
        #expect(engine.status.isMeetingPaused)
        #expect(!engine.status.isIdlePaused)
        #expect(engine.status.activityKind == .meeting)
        #expect(engine.status.isPaused)

        // Ending meeting resumes the fresh focus cycle
        let meetingEndTime = longReturnTime.addingTimeInterval(15 * 60)
        engine.send(.setMeeting(active: false), at: meetingEndTime)
        #expect(!engine.status.isMeetingPaused)
        #expect(engine.status.activityKind == .studying)
        #expect(!engine.status.isPaused)
    }

    @Test
    func meetingEndingDuringIdleClearsPendingSignalAndAllowsNormalFocusOnReturn() {
        var engine = SessionEngine(configuration: configuration, now: startDate)
        let idleStart = startDate.addingTimeInterval(5 * 60)
        engine.send(.beginIdle(startedAt: idleStart), at: idleStart)

        let meetingStart = idleStart.addingTimeInterval(60)
        _ = engine.send(.setMeeting(active: true), at: meetingStart)

        // Meeting ends while user is still idle
        let meetingEnd = idleStart.addingTimeInterval(120)
        let endEffects = engine.send(.setMeeting(active: false), at: meetingEnd)
        #expect(endEffects.isEmpty)
        #expect(engine.status.isIdlePaused)

        // User returns after short idle (< breakDuration)
        let returnTime = idleStart.addingTimeInterval(180)
        let returnEffects = engine.send(.idleReturned(returnedAt: returnTime), at: returnTime)
        #expect(returnEffects.contains(.showIdleBreakPrompt(duration: 180)))

        // User declines idle break -> normal focus resumes
        _ = engine.send(.resolveIdle(acceptedAsBreak: false, returnedAt: returnTime), at: returnTime)
        #expect(engine.status.activityKind == .studying)
        #expect(!engine.status.isPaused)
    }
}
