import AppKit
import CoreGraphics

@MainActor
final class CursorIdleMonitor {
    private var timer: Timer?
    private var idleStartedAt: Date?
    private var monitoringSince = Date()

    var onIdle: ((Date) -> Void)?
    var onReturn: ((Date, Date) -> Void)?

    func start(threshold: TimeInterval) {
        stop()
        monitoringSince = Date()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sample(threshold: threshold) }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        idleStartedAt = nil
    }

    func sample(threshold: TimeInterval, at now: Date = Date()) {
        guard timer != nil else { return }
        let eventTypes: [CGEventType] = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        let secondsSinceMovement = eventTypes.map {
            CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0)
        }.filter { $0.isFinite && $0 >= 0 }.min()

        let lastMovement = secondsSinceMovement.map {
            max(monitoringSince, now.addingTimeInterval(-$0))
        } ?? monitoringSince
        if let idleStartedAt {
            guard lastMovement > idleStartedAt else { return }
            self.idleStartedAt = nil
            onReturn?(idleStartedAt, lastMovement)
        } else if now.timeIntervalSince(lastMovement) >= threshold {
            idleStartedAt = lastMovement
            onIdle?(lastMovement)
        }
    }
}
