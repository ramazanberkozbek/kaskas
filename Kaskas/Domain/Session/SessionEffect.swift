import Foundation

enum SessionEffect: Equatable, Sendable {
    // 1. Overlay dismissals
    case dismissMicroReminder
    case dismissBreakWarning
    case dismissBreak
    case dismissSkippedBreakReminder
    case dismissIdleBreakReminder

    // 2. Overlay presentations
    case showMicroReminder
    case showBreakWarning(endsAt: Date)
    case showBreak(endsAt: Date)
    case showSkippedBreakReminder
    case showIdleBreakPrompt(duration: TimeInterval)

    // 3. Sounds
    case playBreakStartSound
    case playBreakEndSound

    // 4. Persistence
    case persistSession(record: BreakHistoryEntry?, activityKind: ActivityKind?)

    // 5. Scheduler
    case scheduleNextTick(at: Date)
    case cancelScheduler

    var categoryRank: Int {
        switch self {
        case .dismissMicroReminder,
             .dismissBreakWarning,
             .dismissBreak,
             .dismissSkippedBreakReminder,
             .dismissIdleBreakReminder:
            return 10
        case .showMicroReminder,
             .showBreakWarning,
             .showBreak,
             .showSkippedBreakReminder,
             .showIdleBreakPrompt:
            return 20
        case .playBreakStartSound,
             .playBreakEndSound:
            return 30
        case .persistSession:
            return 40
        case .scheduleNextTick,
             .cancelScheduler:
            return 50
        }
    }
}

struct EffectBatch {
    private var dismissals: [SessionEffect] = []
    private var presentations: [SessionEffect] = []
    private var sounds: [SessionEffect] = []
    private var persistence: [SessionEffect] = []
    private var schedulers: [SessionEffect] = []

    mutating func dismiss(_ effects: SessionEffect...) {
        dismissals.append(contentsOf: effects)
    }

    mutating func dismissAllAlerts() {
        dismissals.append(contentsOf: [
            .dismissMicroReminder,
            .dismissBreakWarning,
            .dismissBreak,
            .dismissSkippedBreakReminder,
            .dismissIdleBreakReminder
        ])
    }

    mutating func present(_ effect: SessionEffect) {
        presentations.append(effect)
    }

    mutating func play(_ effect: SessionEffect) {
        sounds.append(effect)
    }

    mutating func persist(record: BreakHistoryEntry? = nil, kind: ActivityKind?) {
        persistence.append(.persistSession(record: record, activityKind: kind))
    }

    mutating func schedule(nextEventDate: Date?, isPaused: Bool) {
        if !isPaused, let next = nextEventDate {
            schedulers.append(.scheduleNextTick(at: next))
        } else {
            schedulers.append(.cancelScheduler)
        }
    }

    func finalized() -> [SessionEffect] {
        dismissals + presentations + sounds + persistence + schedulers
    }
}


