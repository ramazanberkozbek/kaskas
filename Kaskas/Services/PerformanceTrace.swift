import Foundation
import os

/// Event-based diagnostics; no timer, polling, or file writes on the UI thread.
/// Release builds opt in with KASKAS_PERFORMANCE_LOGGING=1.
nonisolated enum PerformanceTrace {
    static let enabled: Bool = {
#if DEBUG
        true
#else
        ProcessInfo.processInfo.environment["KASKAS_PERFORMANCE_LOGGING"] == "1"
#endif
    }()

    private static let logger = Logger(subsystem: "com.ramazanozbek.kaskas", category: "Performance")
    private static let signposter = OSSignposter(subsystem: "com.ramazanozbek.kaskas", category: .pointsOfInterest)

    struct Interval {
        let name: StaticString
        let detail: String
        let start: ContinuousClock.Instant
        let signpost: OSSignpostIntervalState
    }

    static func begin(_ name: StaticString, detail: String = "") -> Interval? {
        guard enabled else { return nil }
        let state = signposter.beginInterval(name, id: signposter.makeSignpostID(), "\(detail, privacy: .public)")
        return Interval(name: name, detail: detail, start: .now, signpost: state)
    }

    static func end(_ interval: Interval?, outcome: String = "completed") {
        guard let interval else { return }
        let duration = interval.start.duration(to: .now).components
        let milliseconds = Double(duration.seconds) * 1000 + Double(duration.attoseconds) / 1e15
        signposter.endInterval(interval.name, interval.signpost, "\(outcome, privacy: .public)")
        logger.notice("\(String(describing: interval.name), privacy: .public) \(interval.detail, privacy: .public) duration_ms=\(milliseconds, format: .fixed(precision: 2)) outcome=\(outcome, privacy: .public)")
    }

    static func measure<Value>(_ name: StaticString, detail: String = "", _ work: () throws -> Value) rethrows -> Value {
        let interval = begin(name, detail: detail)
        defer { end(interval) }
        return try work()
    }
}

@MainActor
final class SettingsNavigationTrace {
    private var pending: (pane: String, interval: PerformanceTrace.Interval?)?

    func selected(_ pane: String) {
        PerformanceTrace.end(pending?.interval, outcome: "superseded")
        pending = (pane, PerformanceTrace.begin("Settings selection to appear", detail: pane))
    }

    func appeared(_ pane: String) {
        guard let pending, pending.pane == pane else { return }
        self.pending = nil
        PerformanceTrace.end(pending.interval)
        // This measures main-queue availability after appearance, not a GPU frame.
        let queued = PerformanceTrace.begin("Settings appear to main queue", detail: pane)
        DispatchQueue.main.async { PerformanceTrace.end(queued) }
    }
}
