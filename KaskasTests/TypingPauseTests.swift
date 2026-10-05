import Foundation
import Testing
@testable import Kaskas

struct TypingPauseTests {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
    private func engine() -> SessionEngine {
        SessionEngine(configuration: FocusConfiguration(focusDuration: 100, pauseDuringMeetings: false), now: start)
    }

    @Test func typingOnlyHoldsTheWarningWindowAndKeepsCountingWork() {
        var engine = engine()
        engine.send(.setTyping(active: true), at: start.addingTimeInterval(50))
        #expect(!engine.status.isPaused)
        let effects = engine.send(.setTyping(active: true), at: start.addingTimeInterval(80))
        #expect(engine.status.isTypingPaused)
        #expect(engine.status.activityKind == .studying)
        #expect(engine.nextEventDate == nil)
        #expect(effects.contains(.showBreakWarning(endsAt: start.addingTimeInterval(100))))
        engine.send(.tick, at: start.addingTimeInterval(200))
        #expect(engine.snapshot(at: start.addingTimeInterval(200)).remaining == 20)
        engine.send(.setTyping(active: false), at: start.addingTimeInterval(203))
        #expect(!engine.status.isPaused)
        #expect(engine.snapshot(at: start.addingTimeInterval(203)).remaining == 20)
        #expect(engine.session.startedAt == start)
        engine.send(.tick, at: start.addingTimeInterval(223))
        #expect(engine.status.phase == .onBreak)
    }

    @Test func eachTypingPauseRestartsTheFullCountdownAfterQuiet() {
        var engine = engine()
        engine.send(.tick, at: start.addingTimeInterval(80))
        engine.send(.setTyping(active: true), at: start.addingTimeInterval(88))
        engine.send(.setTyping(active: true), at: start.addingTimeInterval(120))
        #expect(engine.snapshot(at: start.addingTimeInterval(120)).remaining == 12)
        let effects = engine.send(.setTyping(active: false), at: start.addingTimeInterval(123))
        #expect(engine.snapshot(at: start.addingTimeInterval(123)).remaining == 20)
        #expect(engine.session.startedAt == start)
        #expect(effects.contains(.showBreakWarning(endsAt: start.addingTimeInterval(143))))
        #expect(engine.nextEventDate == start.addingTimeInterval(143))
        engine.send(.setTyping(active: true), at: start.addingTimeInterval(127))
        #expect(engine.snapshot(at: start.addingTimeInterval(200)).remaining == 16)
        engine.send(.setTyping(active: false), at: start.addingTimeInterval(203))
        #expect(engine.snapshot(at: start.addingTimeInterval(203)).remaining == 20)
        #expect(engine.session.startedAt == start)
        engine.send(.tick, at: start.addingTimeInterval(219))
        #expect(engine.status.phase == .focusing)
        engine.send(.tick, at: start.addingTimeInterval(223))
        #expect(engine.status.phase == .onBreak)
    }

    @Test func disablingTypingRestartsTheFullCountdownImmediately() {
        var engine = engine()
        engine.send(.setTyping(active: true), at: start.addingTimeInterval(85))
        var config = engine.configuration
        config.pauseWhileTyping = false
        let effects = engine.send(.updateConfiguration(config), at: start.addingTimeInterval(100))
        #expect(!engine.status.isPaused)
        #expect(engine.snapshot(at: start.addingTimeInterval(100)).remaining == 20)
        #expect(effects.contains(.showBreakWarning(endsAt: start.addingTimeInterval(120))))
        engine.send(.setTyping(active: true), at: start.addingTimeInterval(101))
        #expect(!engine.status.isPaused)
    }

    @Test func warningsDisabledDoNotHoldScheduledBreaks() {
        var engine = engine()
        var config = engine.configuration
        config.breakWarningEnabled = false
        engine.send(.updateConfiguration(config), at: start)
        engine.send(.setTyping(active: true), at: start.addingTimeInterval(100))
        engine.send(.tick, at: start.addingTimeInterval(100))
        #expect(engine.status.phase == .onBreak)
    }

    @Test func explicitActionsStillWorkDuringTyping() {
        for action in [SessionInput.startBreakNow, .skipBreak, .postponeBreak(by: 60), .snooze, .toggleManualPause, .sleep] {
            var engine = engine()
            engine.send(.setTyping(active: true), at: start.addingTimeInterval(85))
            engine.send(action, at: start.addingTimeInterval(100))
            #expect(!engine.status.isTypingPaused)
            switch action {
            case .startBreak: #expect(engine.status.phase == .onBreak)
            case .toggleManualPause: #expect(engine.status.isManualPaused)
            case .systemSuspended: #expect(engine.systemPauseStartedAt == start.addingTimeInterval(100))
            default: #expect(engine.snapshot(at: start.addingTimeInterval(100)).remaining > 20)
            }
        }
    }

    @Test func otherPausesAndExistingBreaksAreNotReplacedByTyping() {
        for action in [SessionInput.toggleManualPause, .sleep, .startBreakNow] {
            var engine = engine()
            engine.send(action, at: start.addingTimeInterval(85))
            let status = engine.status
            engine.send(.setTyping(active: true), at: start.addingTimeInterval(90))
            engine.send(.setTyping(active: false), at: start.addingTimeInterval(100))
            #expect(engine.status == status)
        }
    }

    @Test func meetingTakesOverWithoutCountingTypingAsTimeAway() {
        var engine = engine()
        var config = engine.configuration
        config.pauseDuringMeetings = true
        engine.send(.updateConfiguration(config), at: start)
        engine.send(.setTyping(active: true), at: start.addingTimeInterval(85))
        engine.send(.setProtection(meetingActive: true, videoActive: false), at: start.addingTimeInterval(120))
        #expect(engine.status.isMeetingPaused)
        #expect(engine.meetingPauseStartedAt == start.addingTimeInterval(120))
        engine.send(.setTyping(active: false), at: start.addingTimeInterval(130))
        #expect(engine.status.isMeetingPaused)
        engine.send(.setProtection(meetingActive: false, videoActive: false), at: start.addingTimeInterval(150))
        #expect(!engine.status.isPaused)
        #expect(engine.snapshot(at: start.addingTimeInterval(150)).remaining == 60)
    }

    @Test func restoredTypingIsNotStuck() throws {
        var engine = engine()
        engine.send(.setTyping(active: true), at: start.addingTimeInterval(85))
        let state = try JSONDecoder().decode(SessionState.self, from: JSONEncoder().encode(engine.state))
        var restored = SessionEngine(configuration: engine.configuration, restoredState: state,
                                     lastActiveAt: start.addingTimeInterval(90), now: start.addingTimeInterval(110))
        restored.send(.launch, at: start.addingTimeInterval(110))
        #expect(!restored.status.isTypingPaused)
    }

    @Test func preferencesRoundTripAndOldSettingsDecode() throws {
        var config = FocusConfiguration()
        config.pauseWhileTyping = false
        config.typingPauseIndicatorEnabled = false
        let data = try JSONEncoder().encode(config)
        #expect(try JSONDecoder().decode(FocusConfiguration.self, from: data) == config)
        let old = try JSONDecoder().decode(FocusConfiguration.self, from: Data("{}".utf8))
        #expect(old.pauseWhileTyping)
        #expect(old.typingPauseIndicatorEnabled)
    }

    @MainActor @Test func quietIntervalAndInvalidSamples() {
        #expect(TypingActivityMonitor.isTyping(secondsSinceKeyDown: 0))
        #expect(TypingActivityMonitor.isTyping(secondsSinceKeyDown: 2.99))
        #expect(!TypingActivityMonitor.isTyping(secondsSinceKeyDown: 3))
        #expect(!TypingActivityMonitor.isTyping(secondsSinceKeyDown: -1))
        #expect(!TypingActivityMonitor.isTyping(secondsSinceKeyDown: .nan))
        #expect(!TypingActivityMonitor.isTyping(secondsSinceKeyDown: .infinity))
    }
}

@MainActor
struct TypingPauseIntegrationTests {
    @Test func controllerSamplesBeforeDeadlineAndStopsMonitoringWhenDisabled() throws {
        let suite = "TypingPauseIntegrationTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SessionStore(defaults: defaults)
        var config = FocusConfiguration(focusDuration: 100, pauseDuringMeetings: false, idleDetectionEnabled: false)
        store.save(configuration: config)
        let monitor = TestTypingMonitor()
        let controller = SessionController(store: store, typingMonitor: monitor)
        controller.start()
        defer { controller.stop() }
        #expect(monitor.callback == nil)
        monitor.active = true
        controller.advanceSession(by: 85)
        #expect(controller.sessionSnapshot.status.isTypingPaused)
        #expect(monitor.callback != nil)
        let lateCallback = try #require(monitor.callback)
        config.pauseWhileTyping = false
        controller.updateConfiguration(config)
        #expect(!controller.sessionSnapshot.status.isPaused)
        #expect(abs(controller.sessionSnapshot.remaining - 20) < 0.1)
        #expect(monitor.callback == nil)
        #expect(!store.loadConfiguration().pauseWhileTyping)
        lateCallback(true, Date())
        #expect(!controller.sessionSnapshot.status.isPaused)
    }

    @Test func controllerRestartsFullCountdownAfterQuietSample() throws {
        let suite = "TypingPauseIntegrationTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SessionStore(defaults: defaults)
        store.save(configuration: FocusConfiguration(focusDuration: 100, pauseDuringMeetings: false, idleDetectionEnabled: false))
        let monitor = TestTypingMonitor()
        let controller = SessionController(store: store, typingMonitor: monitor)
        controller.start()
        defer { controller.stop() }
        controller.advanceSession(by: 85)
        #expect(monitor.callback != nil)
        monitor.callback?(true, Date())
        #expect(controller.sessionSnapshot.status.isTypingPaused)
        monitor.callback?(false, Date())
        #expect(!controller.sessionSnapshot.status.isPaused)
        #expect(abs(controller.sessionSnapshot.remaining - 20) < 0.1)
        controller.startBreakNow()
        #expect(monitor.callback == nil)
        #expect(controller.sessionSnapshot.phase == .onBreak)
    }
}

@MainActor
private final class TestTypingMonitor: TypingActivityMonitoring {
    var active = false
    var callback: (@MainActor @Sendable (Bool, Date) -> Void)?
    func sample() -> Bool { active }
    func start(onSample: @escaping @MainActor @Sendable (Bool, Date) -> Void) { callback = onSample }
    func stop() { callback = nil }
}
