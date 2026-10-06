import Foundation

extension SessionEngine {
    @discardableResult
    mutating func send(_ input: SessionInput, at now: Date = Date()) -> [SessionEffect] {
        let hadSchedule = activeHoursState != nil || configuration.activeHours.isEnabled
        let previousWindow = activeHoursState
        var effects = reconcileActiveHours(at: now)
        let outside = activeHoursState?.isOutside == true
        let wasManualBreak = manualBreakActive
        let crossedWindow = previousWindow != activeHoursState
        if outside, !manualBreakActive, case .suspended(var suspension) = status, suspension.reason == .system {
            switch input {
            case .launch, .systemResumed:
                // Time away outside the reminder schedule is not a scheduled break.
                suspension.awaySince = now
                status = .suspended(suspension)
            default: break
            }
        }

        // An idle return outside the window is still activity, but it must not
        // create a natural-break prompt or credit hours outside the schedule.
        switch input {
        case .setTyping where outside:
            break
        case .startBreak(let scheduled) where outside && scheduled:
            break
        case .idleReturned(let returnedAt) where outside || crossedWindow:
            effects += reduce(.resolveIdle(acceptedAsBreak: false, returnedAt: returnedAt), at: now)
        case .resolveIdle(_, let returnedAt) where outside:
            effects += reduce(.resolveIdle(acceptedAsBreak: false, returnedAt: returnedAt), at: now)
        default:
            effects += reduce(input, at: now)
        }
        effects += reconcileActiveHours(at: now)
        guard hadSchedule || configuration.activeHours.isEnabled else { return effects }

        let isOutside = activeHoursState?.isOutside == true
        let allowsManualBreak = manualBreakActive || wasManualBreak
        effects = effects.compactMap { effect in
            switch effect {
            case .scheduleNextTick, .cancelScheduler:
                return nil // Rebuild below: a paused session still needs the next hours boundary.
            case .showMicroReminder, .showBreakWarning, .showSkippedBreakReminder, .showIdleBreakPrompt:
                return isOutside ? nil : effect
            case .showBreak, .playBreakStartSound, .playBreakEndSound:
                return isOutside && !allowsManualBreak ? nil : effect
            case .persistSession(let record, let kind):
                let trackingKind = isOutside && configuration.activeHours.pausesTracking
                    && (kind == .studying || kind == .meeting) ? ActivityKind.kaskasPaused : kind
                return .persistSession(record: record, activityKind: trackingKind)
            default:
                return effect
            }
        }
        // A clock/schedule event must never unpause an explicitly suspended app.
        let isSuspending: Bool
        if case .systemSuspended = input { isSuspending = true } else { isSuspending = false }
        if !isSuspending, !status.isSystemPaused, let next = nextEventDate {
            effects.append(.scheduleNextTick(at: next))
        } else {
            effects.append(.cancelScheduler)
        }
        // Keep dismissals ahead of presentations and persistence ahead of scheduling.
        return effects.enumerated().sorted {
            $0.element.categoryRank == $1.element.categoryRank
                ? $0.offset < $1.offset : $0.element.categoryRank < $1.element.categoryRank
        }.map(\.element)
    }

    /// Applies a schedule transition without using the user's manual-pause state.
    /// Tracking is decided independently, so reminder-only hours still record work.
    mutating func reconcileActiveHours(at now: Date) -> [SessionEffect] {
        let previousState = activeHoursState
        let wasOutside = previousState?.isOutside == true
        let resolved = configuration.activeHours.state(at: now, calendar: activeHoursCalendar)
        let outside = resolved?.isOutside == true

        let isDifferentDay: Bool
        if let prevStart = previousState?.window?.start, let newStart = resolved?.window?.start {
            isDifferentDay = !activeHoursCalendar.isDate(prevStart, inSameDayAs: newStart)
        } else {
            isDifferentDay = false
        }
        let crossedBoundary = previousState != nil && (wasOutside != outside || isDifferentDay)
        activeHoursState = resolved
        var effects: [SessionEffect] = []

        if crossedBoundary && !manualBreakActive {
            var record: BreakHistoryEntry?
            if case .suspended(let s) = status, let pending = s.pendingBreak {
                record = BreakHistoryEntry(id: pending.id, occurredAt: now, startedAt: pending.startedAt,
                    focusStartedAt: pending.focusStartedAt, focusedDuration: pending.focusedDuration,
                    outcome: pending.outcome, source: pending.source)
            } else if status.phase == .onBreak {
                record = .transition(from: session, at: now,
                    outcome: now >= session.endsAt ? .completed : .skipped, source: .scheduled)
            }
            let preserved: Suspension?
            if case .suspended(let suspension) = status,
               [.manual, .meeting, .video, .idle, .system].contains(suspension.reason) {
                preserved = suspension
            } else {
                preserved = nil
            }
            resetFocus(at: now)
            if var suspension = preserved {
                suspension.frozen = status.freeze(at: now)
                suspension.pendingBreak = nil
                // Don't credit an overnight absence as a break in the new window.
                if suspension.reason == .idle || suspension.reason == .system { suspension.awaySince = now }
                status = .suspended(suspension)
            }
            effects += [.dismissMicroReminder, .dismissBreakWarning, .dismissBreak,
                        .dismissSkippedBreakReminder, .dismissIdleBreakReminder]
            effects.append(.persistSession(record: record, activityKind: currentActivityKind(at: now)))
        }

        if outside, case .focusing = status {
            let frozen = FrozenRun.focus(remaining: configuration.focusDuration,
                total: configuration.focusDuration, nextMicroReminderIn: nil, warningShown: false)
            status = .suspended(Suspension(reason: .outsideActiveHours, awaySince: now, frozen: frozen))
            effects += [.dismissMicroReminder, .dismissBreakWarning, .dismissSkippedBreakReminder,
                        .dismissIdleBreakReminder,
                        .persistSession(record: nil, activityKind: currentActivityKind(at: now))]
        } else if !outside, status.isOutsideActiveHours {
            resetFocus(at: now)
            effects.append(.persistSession(record: nil, activityKind: currentActivityKind(at: now)))
        }
        return effects
    }
}
