import Foundation
import Testing
@testable import Kaskas

@MainActor
struct ProtectionIntegrationTests {
    @Test func disabledVideoCannotBeReactivatedByALateCallback() throws {
        let suite = "ProtectionIntegrationTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SessionStore(defaults: defaults)
        var config = FocusConfiguration(pauseDuringMeetings: false, pauseDuringVideo: true, idleDetectionEnabled: false)
        store.save(configuration: config)
        let video = TestVideoMonitor()
        let controller = SessionController(store: store, meetingMonitor: TestMeetingMonitor(), videoMonitor: video)
        controller.start()
        defer { controller.stop() }
        video.emit(true)
        #expect(controller.sessionSnapshot.status.isVideoPaused)
        let lateCallback = try #require(video.callback)
        config.pauseDuringVideo = false
        controller.updateConfiguration(config)
        #expect(!controller.sessionSnapshot.status.isPaused)
        video.active = true
        lateCallback(true)
        controller.reconcile()
        #expect(!controller.sessionSnapshot.status.isPaused)
        #expect(!SessionStore(defaults: defaults).loadConfiguration().pauseDuringVideo)
    }

    @Test func meetingEndDoesNotResumeAnOngoingVideo() throws {
        let suite = "ProtectionIntegrationTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SessionStore(defaults: defaults)
        store.save(configuration: FocusConfiguration(pauseDuringVideo: true, idleDetectionEnabled: false))
        let video = TestVideoMonitor()
        let meeting = TestMeetingMonitor()
        let controller = SessionController(store: store, meetingMonitor: meeting, videoMonitor: video)
        controller.start()
        defer { controller.stop() }
        video.emit(true)
        meeting.emit(true)
        #expect(controller.sessionSnapshot.status.isMeetingPaused)
        meeting.emit(false)
        #expect(controller.sessionSnapshot.status.isVideoPaused)
        video.emit(false)
        #expect(!controller.sessionSnapshot.status.isPaused)
    }

    @Test func newPreferencesSurviveReopening() throws {
        let suite = "ProtectionIntegrationTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var config = FocusConfiguration()
        config.pauseDuringVideo = true
        config.videoPauseIndicatorEnabled = false
        config.meetingCameraDetectionEnabled = true
        config.meetingVirtualMicrophonesEnabled = true
        config.meetingExcludedBundleIDs = ["custom.meeting.exclusion"]
        config.meetingExcludedDeviceUIDs = ["device-uid"]
        config.videoExcludedBundleIDs = ["com.google.Chrome"]
        SessionStore(defaults: defaults).save(configuration: config)
        #expect(SessionStore(defaults: defaults).loadConfiguration() == config)
    }
}

@MainActor
private final class TestVideoMonitor: VideoActivityMonitoring {
    var active = false
    var callback: ((Bool) -> Void)?
    func start(excludedBundleIDs: [String], onChange: @escaping (Bool) -> Void) { callback = onChange }
    func stop() { callback = nil; active = false }
    func sample() -> Bool { active }
    func emit(_ active: Bool) { self.active = active; callback?(active) }
}

@MainActor
private final class TestMeetingMonitor: MeetingActivityMonitoring {
    var active = false
    var callback: ((Bool) -> Void)?
    func start(onChange: @escaping (Bool) -> Void) { callback = onChange }
    func stop() { callback = nil }
    func sample() -> Bool { active }
    func emit(_ active: Bool) { self.active = active; callback?(active) }
}
