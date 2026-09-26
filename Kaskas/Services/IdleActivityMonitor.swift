import AppKit
import CoreGraphics

@MainActor
final class IdleActivityMonitor {
    private var timer: Timer?

    func start(onSample: @escaping @MainActor @Sendable (Date, TimeInterval) -> Void) {
        stop()
        let timer = Timer(timeInterval: 1, repeats: true) { _ in
            let idleSeconds = CGEventSource.secondsSinceLastEventType(
                .hidSystemState, eventType: .null
            )
            guard idleSeconds.isFinite, idleSeconds >= 0 else { return }
            Task { @MainActor in onSample(Date(), idleSeconds) }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        let idleSeconds = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .null)
        if idleSeconds.isFinite, idleSeconds >= 0 {
            onSample(Date(), idleSeconds)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
