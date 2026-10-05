import CoreGraphics
import Foundation

@MainActor
protocol TypingActivityMonitoring: AnyObject {
    func sample() -> Bool
    func start(onSample: @escaping @MainActor @Sendable (Bool, Date) -> Void)
    func stop()
}

/// Reads only elapsed time since a key press, never key codes or typed text.
@MainActor
final class TypingActivityMonitor: TypingActivityMonitoring {
    static let quietInterval: TimeInterval = 3
    private var timer: Timer?

    static func isTyping(secondsSinceKeyDown: TimeInterval) -> Bool {
        secondsSinceKeyDown.isFinite && secondsSinceKeyDown >= 0 && secondsSinceKeyDown < quietInterval
    }

    static var isTyping: Bool {
        isTyping(secondsSinceKeyDown: CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .keyDown))
    }

    func sample() -> Bool { Self.isTyping }

    /// Fast sampling is needed only while the pre-break countdown is visible.
    func start(onSample: @escaping @MainActor @Sendable (Bool, Date) -> Void) {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 0.25, repeats: true) { _ in
            MainActor.assumeIsolated { onSample(Self.isTyping, Date()) }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
