import Foundation

// MARK: - Unified State Transition Reducer

extension SessionEngine {
    @discardableResult
    mutating func send(
        _ input: SessionInput,
        at now: Date = Date()
    ) -> [SessionEffect] {
        var effects = EffectBatch()

        switch input {
        case .launch(let meetingActive):
            var naturalBreakEntry: BreakHistoryEntry?

            if case .suspended(let s) = status, s.reason == .system {
                naturalBreakEntry = endSystemPause(at: now, meetingActive: meetingActive)
                if status.phase == .onBreak {
                    prepareForLaunch(at: now)
                }
            } else if !status.isPaused {
                prepareForLaunch(at: now)
                if meetingActive {
                    beginMeetingPause(at: now)
                }
            }

            effects.dismissAllAlerts()
            // Restored breaks are recorded silently; their end was not observed live.
            effects.persist(record: naturalBreakEntry, kind: currentActivityKind(at: now))
            effects.schedule(nextEventDate: nextEventDate, isPaused: status.isPaused)

        case .tick:
            guard !status.isPaused else {
                return [.cancelScheduler]
            }

            let previousSession = self.session
            let events = process(at: now)

            for event in events {
                switch event {
                case .microReminderDue:
                    effects.present(.showMicroReminder)
                    effects.persist(kind: currentActivityKind(at: now))

                case .breakApproaching:
                    effects.dismiss(.dismissMicroReminder)
                    if configuration.breakWarningEnabled {
                        effects.present(.showBreakWarning(endsAt: session.endsAt))
                    }
                    effects.persist(kind: currentActivityKind(at: now))

                case .fullBreakDue:
                    effects.dismiss(.dismissMicroReminder, .dismissBreakWarning)
                    effects.present(.showBreak(endsAt: session.endsAt))
                    effects.play(.playBreakStartSound)
                    effects.persist(kind: currentActivityKind(at: now))

                case .breakEnded:
                    effects.dismiss(.dismissBreak)
                    effects.play(.playBreakEndSound)
                    let completedBreak = BreakHistoryEntry.transition(
                        from: previousSession, at: now, outcome: .completed, source: .scheduled
                    )
                    effects.persist(record: completedBreak, kind: currentActivityKind(at: now))
                }
            }

            effects.schedule(nextEventDate: nextEventDate, isPaused: status.isPaused)

        case .toggleManualPause:
            return send(.setManualPause(active: !status.isManualPaused), at: now)

        case .setManualPause(let active):
            if active {
                guard !status.isManualPaused else { return [] }
                if status.isIdlePaused {
                    declineIdleBreak(at: now)
                    effects.dismiss(.dismissIdleBreakReminder)
                }
                beginManualPause(at: now)
                effects.dismissAllAlerts()
                effects.persist(kind: .kaskasPaused)
                effects.schedule(nextEventDate: nextEventDate, isPaused: status.isPaused)
            } else {
                guard status.isManualPaused else { return [] }
                endManualPause(at: now)
                if status.phase == .onBreak {
                    effects.present(.showBreak(endsAt: session.endsAt))
                }
                effects.persist(kind: currentActivityKind(at: now))
                effects.schedule(nextEventDate: nextEventDate, isPaused: status.isPaused)
            }

        case .setMeeting(let active):
            if active {
                if case .focusing = status {
                    beginMeetingPause(at: now)
                    effects.dismiss(.dismissMicroReminder, .dismissBreakWarning)
                    effects.persist(kind: .meeting)
                    effects.schedule(nextEventDate: nextEventDate, isPaused: status.isPaused)
                } else if case .suspended(var s) = status, s.reason == .idle {
                    s.meetingPending = true
                    status = .suspended(s)
                    return []
                } else {
                    return []
                }
            } else {
                if case .suspended(var s) = status, s.reason == .idle, s.meetingPending {
                    s.meetingPending = false
                    status = .suspended(s)
                    return []
                }
                guard status.isMeetingPaused else { return [] }
                endMeetingPause(at: now)
                effects.persist(kind: currentActivityKind(at: now))
                effects.schedule(nextEventDate: nextEventDate, isPaused: status.isPaused)
            }

        case .beginIdle(let startedAt):
            guard case .focusing = status else { return [] }
            let idleStart = max(session.startedAt, startedAt)
            beginIdlePause(at: idleStart)
            effects.dismiss(.dismissMicroReminder, .dismissBreakWarning)
            effects.persist(kind: .computerInactive)
            effects.schedule(nextEventDate: nextEventDate, isPaused: status.isPaused)

        case .idleReturned(let returnedAt):
            guard case .suspended(let s) = status, s.reason == .idle else { return [] }
            let awayDuration = max(0, returnedAt.timeIntervalSince(s.awaySince))
            if awayDuration >= activeConfiguration.breakDuration {
                let prev = session
                recordCompletedBreak(at: returnedAt)
                startFocus(at: returnedAt)
                let record = BreakHistoryEntry.idleBreak(
                    from: prev, startedAt: s.awaySince, returnedAt: returnedAt
                )
                effects.dismiss(.dismissIdleBreakReminder)
                if s.meetingPending {
                    beginMeetingPause(at: returnedAt)
                    effects.persist(record: record, kind: .meeting)
                } else {
                    effects.play(.playBreakEndSound)
                    effects.persist(record: record, kind: .studying)
                }
                effects.schedule(nextEventDate: nextEventDate, isPaused: status.isPaused)
            } else {
                if s.meetingPending {
                    status = .suspended(Suspension(
                        reason: .meeting,
                        awaySince: returnedAt,
                        frozen: s.frozen,
                        meetingPending: false
                    ))
                    effects.dismiss(.dismissIdleBreakReminder)
                    effects.persist(kind: .meeting)
                    effects.schedule(nextEventDate: nextEventDate, isPaused: status.isPaused)
                } else {
                    effects.present(.showIdleBreakPrompt(duration: awayDuration))
                }
            }

        case .resolveIdle(let acceptedAsBreak, let returnedAt):
            guard case .suspended(let s) = status, s.reason == .idle else { return [] }
            effects.dismiss(.dismissIdleBreakReminder)
            let prev = session
            if acceptedAsBreak {
                recordCompletedBreak(at: returnedAt)
                startFocus(at: returnedAt)
                let record = BreakHistoryEntry.idleBreak(
                    from: prev, startedAt: s.awaySince, returnedAt: returnedAt
                )
                if s.meetingPending {
                    beginMeetingPause(at: returnedAt)
                    effects.persist(record: record, kind: .meeting)
                } else {
                    effects.play(.playBreakEndSound)
                    effects.persist(record: record, kind: .studying)
                }
            } else {
                if s.meetingPending {
                    status = .suspended(Suspension(
                        reason: .meeting,
                        awaySince: returnedAt,
                        frozen: s.frozen,
                        meetingPending: false
                    ))
                    effects.persist(kind: .meeting)
                } else {
                    declineIdleBreak(at: returnedAt)
                    effects.persist(kind: .studying)
                }
            }
            effects.schedule(nextEventDate: nextEventDate, isPaused: status.isPaused)

        case .systemSuspended(let cause):
            suspend(reason: .system, at: now)
            effects.dismissAllAlerts()
            let kind: ActivityKind = cause == .quit ? .kaskasPaused : .computerInactive
            effects.persist(kind: kind)
            effects.schedule(nextEventDate: nextEventDate, isPaused: status.isPaused)

        case .systemResumed(let meetingActive):
            guard case .suspended(let s) = status, s.reason == .system else { return [] }
            let naturalBreakEntry = endSystemPause(at: now, meetingActive: meetingActive)

            if naturalBreakEntry != nil {
                effects.dismiss(.dismissBreak)
                // Do not replay a break-end alert after sleep or screen unlock.
            } else if case .onBreak(let r) = status {
                effects.present(.showBreak(endsAt: r.endsAt))
            }

            effects.persist(record: naturalBreakEntry, kind: currentActivityKind(at: now))
            effects.schedule(nextEventDate: nextEventDate, isPaused: status.isPaused)

        case .startBreak(let scheduled):
            if case .suspended(let s) = status, s.reason == .idle {
                declineIdleBreak(at: now)
                effects.dismiss(.dismissIdleBreakReminder)
            }
            effects.dismiss(.dismissMicroReminder, .dismissSkippedBreakReminder, .dismissBreakWarning)
            startBreak(at: now, scheduled: scheduled)
            effects.present(.showBreak(endsAt: session.endsAt))
            effects.play(.playBreakStartSound)
            effects.persist(kind: currentActivityKind(at: now))
            effects.schedule(nextEventDate: session.endsAt, isPaused: false)

        case .completeBreak:
            let prev = session
            let wasOnBreak = prev.phase == .onBreak
            effects.dismiss(.dismissBreakWarning, .dismissBreak)
            completeBreak(at: now)
            if wasOnBreak {
                effects.play(.playBreakEndSound)
            }
            let record = wasOnBreak ? BreakHistoryEntry.transition(
                from: prev, at: now, outcome: .completed, source: .manual
            ) : nil
            effects.persist(record: record, kind: currentActivityKind(at: now))
            effects.schedule(nextEventDate: nextEventDate, isPaused: status.isPaused)

        case .skipBreak:
            let prev = session
            effects.dismiss(.dismissBreakWarning, .dismissBreak)
            let shouldSuggest = skipBreak(at: now)
            if shouldSuggest {
                effects.present(.showSkippedBreakReminder)
            }
            let record = BreakHistoryEntry.transition(
                from: prev, at: now, outcome: .skipped, source: .manual
            )
            effects.persist(record: record, kind: currentActivityKind(at: now))
            effects.schedule(nextEventDate: nextEventDate, isPaused: status.isPaused)

        case .snooze:
            snooze()
            effects.dismiss(.dismissBreakWarning)
            effects.persist(kind: currentActivityKind(at: now))
            effects.schedule(nextEventDate: nextEventDate, isPaused: status.isPaused)

        case .snoozeBreak:
            snoozeBreak(at: now)
            effects.dismiss(.dismissBreak)
            effects.persist(kind: currentActivityKind(at: now))
            effects.schedule(nextEventDate: nextEventDate, isPaused: status.isPaused)

        case .postponeBreak(let duration):
            postponeBreak(by: duration)
            effects.dismiss(.dismissBreakWarning)
            effects.persist(kind: currentActivityKind(at: now))
            effects.schedule(nextEventDate: nextEventDate, isPaused: status.isPaused)

        case .updateConfiguration(let newConfig):
            let oldWarningEnabled = configuration.breakWarningEnabled
            let oldWarningLeadTime = configuration.breakWarningLeadTime
            let oldFocusDuration = configuration.focusDuration
            updateConfiguration(newConfig, at: now)
            if oldWarningEnabled != newConfig.breakWarningEnabled
                || oldWarningLeadTime != newConfig.breakWarningLeadTime
                || oldFocusDuration != newConfig.focusDuration {
                effects.dismiss(.dismissBreakWarning)
            }
            effects.persist(kind: currentActivityKind(at: now))
            effects.schedule(nextEventDate: nextEventDate, isPaused: status.isPaused)
        }

        return effects.finalized()
    }
}

// MARK: - Private State Transitions & Lifecycle Helpers

fileprivate extension SessionEngine {
    mutating func prepareForLaunch(at now: Date = Date()) {
        guard !status.isPaused else { return }
        switch status {
        case .onBreak:
            startFocus(at: now)
        case .focusing(var run):
            if (configuration.breakWarningEnabled
                && run.endsAt.timeIntervalSince(now) <= configuration.breakWarningLeadTime)
                || (configuration.breakWarningEnabled && run.warningShown) {
                startFocus(at: now)
                return
            }

            if let reminderAt = run.nextMicroReminderAt, reminderAt <= now {
                run.nextMicroReminderAt = nextFutureMicroReminder(
                    after: reminderAt,
                    relativeTo: now,
                    focusEndsAt: run.endsAt
                )
                status = .focusing(run)
            }
        case .suspended:
            break
        }
    }

    mutating func updateConfiguration(
        _ configuration: FocusConfiguration,
        at now: Date = Date()
    ) {
        let microReminderChanged = configuration.microReminderInterval != self.configuration.microReminderInterval
            || configuration.microReminderInterval != activeConfiguration.microReminderInterval

        if case .focusing = status,
           configuration.focusDuration != self.configuration.focusDuration {
            activeConfiguration.focusDuration = configuration.focusDuration
            activeConfiguration.microReminderInterval = configuration.microReminderInterval
            status = .focusing(Self.makeFocusRun(
                duration: activeConfiguration.focusDuration,
                microReminderInterval: activeConfiguration.microReminderInterval,
                at: now
            ))
        } else if microReminderChanged {
            activeConfiguration.microReminderInterval = configuration.microReminderInterval
            if case .focusing(var run) = status {
                let nextReminder = now.addingTimeInterval(configuration.microReminderInterval)
                run.nextMicroReminderAt = nextReminder < run.endsAt ? nextReminder : nil
                status = .focusing(run)
            } else if case .suspended(var suspension) = status {
                if case .focus(let remaining, let total, _, let warningShown) = suspension.frozen {
                    let nextReminderIn = configuration.microReminderInterval < remaining
                        ? configuration.microReminderInterval
                        : nil
                    suspension.frozen = .focus(
                        remaining: remaining,
                        total: total,
                        nextMicroReminderIn: nextReminderIn,
                        warningShown: warningShown
                    )
                    status = .suspended(suspension)
                }
            }
        }
        self.configuration = configuration
        if !configuration.pauseDuringMeetings, status.isMeetingPaused {
            endMeetingPause(at: now)
        }
    }

    mutating func process(at now: Date = Date()) -> [SessionEvent] {
        guard !status.isPaused else { return [] }
        switch status {
        case .focusing(var run):
            if now >= run.endsAt {
                startBreak(at: now)
                return [.fullBreakDue]
            }

            let warningAt = max(
                run.startedAt,
                run.endsAt.addingTimeInterval(-configuration.breakWarningLeadTime)
            )
            if configuration.breakWarningEnabled, !run.warningShown, now >= warningAt {
                run.warningShown = true
                run.nextMicroReminderAt = run.nextMicroReminderAt.flatMap { reminderAt in
                    now >= reminderAt
                        ? nextFutureMicroReminder(
                            after: reminderAt,
                            relativeTo: now,
                            focusEndsAt: run.endsAt
                        )
                        : reminderAt
                }
                status = .focusing(run)
                return [.breakApproaching]
            }

            guard let reminderAt = run.nextMicroReminderAt, now >= reminderAt else {
                return []
            }

            run.nextMicroReminderAt = nextFutureMicroReminder(
                after: reminderAt,
                relativeTo: now,
                focusEndsAt: run.endsAt
            )
            status = .focusing(run)
            return [.microReminderDue]

        case .onBreak(let run):
            guard now >= run.endsAt else {
                return []
            }

            recordCompletedBreak(at: now)
            startFocus(at: now)
            return [.breakEnded]

        case .suspended:
            return []
        }
    }

    mutating func startBreak(at now: Date = Date(), scheduled: Bool = true) {
        if scheduled && activeConfiguration.longBreakEnabled { scheduledBreakCount += 1 }
        let isLongBreak = scheduled
            && activeConfiguration.longBreakEnabled
            && scheduledBreakCount % activeConfiguration.longBreakFrequency == 0
        let kind: ScheduledBreakKind = isLongBreak ? .long : .short
        let duration = isLongBreak
            ? activeConfiguration.longBreakDuration
            : activeConfiguration.breakDuration
        status = .onBreak(BreakRun(
            kind: kind,
            startedAt: now,
            endsAt: now.addingTimeInterval(duration)
        ))
    }

    mutating func completeBreak(at now: Date = Date()) {
        if case .onBreak = status {
            recordCompletedBreak(at: now)
        }
        startFocus(at: now)
    }

    @discardableResult
    mutating func skipBreak(at now: Date = Date()) -> Bool {
        if case .onBreak(let run) = status,
           now.timeIntervalSince(run.startedAt) >= Self.meaningfulBreakDuration {
            consecutiveSkippedBreaks = 0
            startFocus(at: now)
            return false
        }
        consecutiveSkippedBreaks += 1
        startFocus(at: now)
        return consecutiveSkippedBreaks % 3 == 0
    }

    mutating func recordCompletedBreak(at now: Date) {
        completedBreaks = breaksTakenToday(at: now) + 1
        completedBreaksDay = now
        consecutiveSkippedBreaks = 0
    }

    mutating func snooze() {
        guard case .focusing(var run) = status else { return }
        run.endsAt = run.endsAt.addingTimeInterval(activeConfiguration.snoozeDuration)
        run.warningShown = false
        status = .focusing(run)
    }

    mutating func postponeBreak(by duration: TimeInterval) {
        guard case .focusing(var run) = status else { return }
        run.endsAt = run.endsAt.addingTimeInterval(max(1, duration))
        run.warningShown = duration <= configuration.breakWarningLeadTime
        status = .focusing(run)
    }

    mutating func snoozeBreak(at now: Date = Date()) {
        let endsAt = now.addingTimeInterval(activeConfiguration.snoozeDuration)
        status = .focusing(FocusRun(
            startedAt: now,
            endsAt: endsAt,
            nextMicroReminderAt: nil,
            warningShown: false
        ))
    }

    mutating func startFocus(at now: Date) {
        if activeConfiguration.longBreakEnabled != configuration.longBreakEnabled
            || activeConfiguration.longBreakFrequency != configuration.longBreakFrequency {
            scheduledBreakCount = 0
        }
        activeConfiguration = configuration
        status = .focusing(Self.makeFocusRun(
            duration: activeConfiguration.focusDuration,
            microReminderInterval: activeConfiguration.microReminderInterval,
            at: now
        ))
    }

    func freeze(at now: Date) -> FrozenRun {
        status.freeze(at: now)
    }

    mutating func suspend(reason: SuspendReason, at now: Date) {
        switch status {
        case .focusing, .onBreak:
            let frozen = freeze(at: now)
            status = .suspended(Suspension(reason: reason, awaySince: now, frozen: frozen))
        case .suspended(var suspension):
            if suspension.reason == .meeting && reason == .system {
                suspension.reason = .system
                suspension.meetingPending = true
                status = .suspended(suspension)
            } else if suspension.reason != .manual {
                suspension.reason = reason
                status = .suspended(suspension)
            }
        }
    }

    mutating func resume(at now: Date, grace: TimeInterval = 0) {
        guard case .suspended(let suspension) = status else { return }
        switch suspension.frozen {
        case .focus(let remaining, let total, _, let warningShown):
            let effectiveRemaining = remaining + grace
            let endsAt = now.addingTimeInterval(effectiveRemaining)
            let startedAt = endsAt.addingTimeInterval(-total)
            let firstReminder = nextFutureMicroReminder(
                after: startedAt,
                relativeTo: now,
                focusEndsAt: endsAt
            )
            let effectiveWarningShown = grace > 0 ? false : warningShown
            status = .focusing(FocusRun(
                startedAt: startedAt,
                endsAt: endsAt,
                nextMicroReminderAt: firstReminder,
                warningShown: effectiveWarningShown
            ))
        case .breakTime(let kind, let remaining, let total):
            let endsAt = now.addingTimeInterval(remaining + grace)
            let startedAt = endsAt.addingTimeInterval(-total)
            status = .onBreak(BreakRun(kind: kind, startedAt: startedAt, endsAt: endsAt))
        }
    }

    mutating func beginMeetingPause(at now: Date) {
        guard case .focusing = status else { return }
        suspend(reason: .meeting, at: now)
    }

    mutating func endMeetingPause(at now: Date) {
        guard case .suspended(let suspension) = status, suspension.reason == .meeting else { return }
        resume(at: now, grace: Self.meetingResumeDelay)
    }

    mutating func beginManualPause(at now: Date) {
        if status.isManualPaused { return }
        suspend(reason: .manual, at: now)
    }

    mutating func endManualPause(at now: Date) {
        guard case .suspended(let suspension) = status, suspension.reason == .manual else { return }
        resume(at: now)
    }

    mutating func beginIdlePause(at now: Date) {
        guard case .focusing = status else { return }
        suspend(reason: .idle, at: now)
    }

    mutating func declineIdleBreak(at now: Date) {
        guard case .suspended(let suspension) = status, suspension.reason == .idle else { return }
        let remainingAtPause: TimeInterval
        if case .focus(let remaining, _, _, _) = suspension.frozen {
            remainingAtPause = remaining
        } else {
            remainingAtPause = 0
        }
        let resumeGrace = max(0, Self.systemResumeGrace - remainingAtPause)
        resume(at: now, grace: resumeGrace)
    }

    mutating func endSystemPause(at now: Date, meetingActive: Bool) -> BreakHistoryEntry? {
        guard case .suspended(let suspension) = status, suspension.reason == .system else { return nil }

        if meetingActive {
            status = .suspended(Suspension(
                reason: .meeting,
                awaySince: now,
                frozen: suspension.frozen,
                meetingPending: false
            ))
            return nil
        }

        let awayDuration = max(0, now.timeIntervalSince(suspension.awaySince))
        if suspension.meetingPending {
            if awayDuration >= activeConfiguration.breakDuration {
                let entry = BreakHistoryEntry.transition(
                    from: session,
                    startedAt: suspension.awaySince,
                    at: now,
                    outcome: .completed,
                    source: .scheduled
                )
                recordCompletedBreak(at: now)
                startFocus(at: now)
                return entry
            } else {
                resume(at: now, grace: Self.meetingResumeDelay)
                return nil
            }
        }

        switch suspension.frozen {
        case .focus(let remaining, _, _, _):
            if awayDuration >= activeConfiguration.breakDuration {
                let entry = BreakHistoryEntry.transition(
                    from: session,
                    startedAt: suspension.awaySince,
                    at: now,
                    outcome: .completed,
                    source: .scheduled
                )
                recordCompletedBreak(at: now)
                startFocus(at: now)
                return entry
            }

            let grace = max(0, Self.systemResumeGrace - remaining)
            resume(at: now, grace: grace)

        case .breakTime(_, let remaining, _):
            if awayDuration >= remaining {
                let entry = BreakHistoryEntry.transition(
                    from: session,
                    startedAt: suspension.awaySince,
                    at: now,
                    outcome: .completed,
                    source: .scheduled
                )
                recordCompletedBreak(at: now)
                startFocus(at: now)
                return entry
            }

            resume(at: now)
        }

        return nil
    }

    func nextFutureMicroReminder(
        after reminderAt: Date,
        relativeTo now: Date,
        focusEndsAt: Date
    ) -> Date? {
        let elapsedIntervals = floor(
            now.timeIntervalSince(reminderAt) / activeConfiguration.microReminderInterval
        ) + 1
        let nextReminderAt = reminderAt.addingTimeInterval(
            elapsedIntervals * activeConfiguration.microReminderInterval
        )

        return nextReminderAt < focusEndsAt ? nextReminderAt : nil
    }
}
