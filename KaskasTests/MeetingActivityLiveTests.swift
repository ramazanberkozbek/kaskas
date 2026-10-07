import Foundation
import Testing
@testable import Kaskas

/// Manual hardware regression: open a solo Zoom call with the physical microphone
/// unmuted and close other microphone consumers. Opt in with
/// TEST_RUNNER_KASKAS_LIVE_ZOOM_TEST=1 xcodebuild test ...
/// Ordinary test runs do not depend on installed apps or microphone activity.
@MainActor
struct MeetingActivityLiveTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["KASKAS_LIVE_ZOOM_TEST"] == "1"))
    func zoomInputPausesSessionAndRespectsApplicationExclusion() async throws {
        let suite = "MeetingActivityLiveTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SessionStore(defaults: defaults)
        var configuration = FocusConfiguration(pauseDuringVideo: false, idleDetectionEnabled: false)
        configuration.meetingPauseIndicatorEnabled = false
        store.save(configuration: configuration)
        let monitor = MeetingActivityMonitor()
        let controller = SessionController(store: store, meetingMonitor: monitor)
        controller.start()
        defer { controller.stop() }
        try await Task.sleep(for: .seconds(3))
        #expect(monitor.sample(), "Zoom's physical microphone input must be detected")
        #expect(controller.sessionSnapshot.status.isMeetingPaused)

        configuration.meetingExcludedBundleIDs.append("us.zoom.xos")
        controller.updateConfiguration(configuration)
        try await Task.sleep(for: .seconds(3))
        #expect(!monitor.sample(), "Excluding Zoom must suppress its microphone activity")
        #expect(!controller.sessionSnapshot.status.isMeetingPaused)

        configuration.meetingExcludedBundleIDs.removeAll { $0 == "us.zoom.xos" }
        controller.updateConfiguration(configuration)
        try await Task.sleep(for: .seconds(3))
        #expect(monitor.sample())
        #expect(controller.sessionSnapshot.status.isMeetingPaused)
    }
}
