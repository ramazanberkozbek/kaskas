import AppKit
import CoreGraphics

/// Monitors user input events to detect inactivity and return.
@MainActor
final class CursorIdleMonitor {
    private var timer: Timer?
    private var state = IdleInputState(monitoringSince: Date())

    var shouldDetectIdle: (() -> Bool)?

    var onIdle: ((Date) -> Void)?
    var onReturn: ((Date, Date) -> Void)?

    func start(threshold: TimeInterval) {
        stop()
        state = IdleInputState(monitoringSince: Date())
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sample(threshold: threshold) }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        state.reset()
    }

    func sample(threshold: TimeInterval, at now: Date = Date()) {
        guard timer != nil else { return }
        // The Swift overlay does not import kCGAnyInputEventType (defined as ~0 in the SDK).
        let anyInput = CGEventType(rawValue: UInt32.max)!
        let eventCount = CGEventSource.counterForEventType(.hidSystemState, eventType: anyInput)
        if shouldDetectIdle?() == false {
            // Passive viewing is not proof that the user left their computer.
            state = IdleInputState(monitoringSince: now)
            return
        }
        let secondsSinceInput = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: anyInput)
        switch state.sample(at: now, threshold: threshold, secondsSinceInput: secondsSinceInput, eventCount: eventCount) {
        case .idle(let startedAt): onIdle?(startedAt)
        case .returned(let startedAt, let returnedAt): onReturn?(startedAt, returnedAt)
        case nil: break
        }
    }
}

struct IdleInputState {
    enum Transition: Equatable {
        case idle(Date)
        case returned(Date, Date)
    }

    let monitoringSince: Date
    private(set) var idleStartedAt: Date?
    private var eventCountAtIdle: UInt32?

    init(monitoringSince: Date) {
        self.monitoringSince = monitoringSince
    }

    mutating func reset() {
        idleStartedAt = nil
        eventCountAtIdle = nil
    }

    mutating func sample(
        at now: Date,
        threshold: TimeInterval,
        secondsSinceInput: TimeInterval,
        eventCount: UInt32
    ) -> Transition? {
        if let idleStartedAt {
            guard eventCount != eventCountAtIdle else { return nil }
            reset()
            return .returned(idleStartedAt, now)
        }

        let lastInput = secondsSinceInput.isFinite && secondsSinceInput >= 0
            ? max(monitoringSince, now.addingTimeInterval(-secondsSinceInput))
            : monitoringSince
        guard now.timeIntervalSince(lastInput) >= threshold else { return nil }
        idleStartedAt = lastInput
        eventCountAtIdle = eventCount
        return .idle(lastInput)
    }
}
