import Foundation
import IOKit.pwr_mgt
import Testing
@testable import Kaskas

struct ProtectionTests {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000_000)

    private func engine() -> SessionEngine {
        SessionEngine(configuration: FocusConfiguration(pauseDuringVideo: true), now: start)
    }

    @Test func overlappingReasonsFreezeOnceAndResumeOnlyAfterBothEnd() {
        var engine = engine()
        let pause = start.addingTimeInterval(10)
        engine.send(.setProtection(meetingActive: true, videoActive: true), at: pause)
        let frozen = engine.snapshot(at: pause).remaining
        #expect(engine.status.isMeetingPaused)
        engine.send(.setProtection(meetingActive: false, videoActive: true), at: pause.addingTimeInterval(100))
        #expect(engine.status.isVideoPaused)
        #expect(engine.snapshot(at: pause.addingTimeInterval(100)).remaining == frozen)
        engine.send(.setProtection(meetingActive: false, videoActive: false), at: pause.addingTimeInterval(200))
        #expect(!engine.status.isPaused)
        #expect(engine.snapshot(at: pause.addingTimeInterval(200)).remaining == frozen)
    }

    @Test func protectionOnlyTopsUpWhenLessThanOneMinuteRemains() {
        for meeting in [false, true] {
            for remaining in [15.0, 60.0, 120.0] {
                var engine = engine()
                let pause = start.addingTimeInterval(engine.configuration.focusDuration - remaining)
                engine.send(.setProtection(meetingActive: meeting, videoActive: !meeting), at: pause)
                let end = pause.addingTimeInterval(100)
                engine.send(.setProtection(meetingActive: false, videoActive: false), at: end)
                #expect(engine.snapshot(at: end).remaining == max(60, remaining))
            }
        }
    }

    @Test func disablingVideoRejectsOldSignalsAndKeepsMeetingPause() {
        var engine = engine()
        engine.send(.setProtection(meetingActive: true, videoActive: true), at: start)
        var config = engine.configuration
        config.pauseDuringVideo = false
        engine.send(.updateConfiguration(config), at: start.addingTimeInterval(1))
        #expect(engine.status.isMeetingPaused)
        engine.send(.setProtection(meetingActive: false, videoActive: true), at: start.addingTimeInterval(2))
        #expect(!engine.status.isPaused)
        engine.send(.setProtection(meetingActive: false, videoActive: true), at: start.addingTimeInterval(3))
        #expect(!engine.status.isPaused)
    }

    @Test func disablingMeetingKeepsVideoPauseWithoutAddingGrace() {
        var engine = engine()
        engine.send(.setProtection(meetingActive: true, videoActive: true), at: start)
        var config = engine.configuration
        config.pauseDuringMeetings = false
        engine.send(.updateConfiguration(config), at: start.addingTimeInterval(20))
        #expect(engine.status.isVideoPaused)
        #expect(engine.snapshot(at: start.addingTimeInterval(20)).remaining == config.focusDuration)
    }

    @Test func sleepWakeRetainsOnlyCurrentProtectionSignals() {
        var engine = engine()
        engine.send(.setProtection(meetingActive: false, videoActive: true), at: start)
        engine.send(.sleep, at: start.addingTimeInterval(10))
        #expect(engine.status.isSystemPaused)
        engine.send(.systemResumed(meetingActive: false, videoActive: true), at: start.addingTimeInterval(100))
        #expect(engine.status.isVideoPaused)
        engine.send(.setProtection(meetingActive: false, videoActive: false), at: start.addingTimeInterval(110))
        #expect(!engine.status.isPaused)
    }

    @Test func manualPauseWinsAndVideoDoesNotInterruptAnExistingBreak() {
        var engine = engine()
        engine.send(.setManualPause(active: true), at: start)
        engine.send(.setProtection(meetingActive: false, videoActive: true), at: start.addingTimeInterval(1))
        #expect(engine.status.isManualPaused)
        engine.send(.setManualPause(active: false), at: start.addingTimeInterval(2))
        #expect(engine.status.isVideoPaused)
        engine.send(.startBreakNow, at: start.addingTimeInterval(3))
        engine.send(.setProtection(meetingActive: false, videoActive: true), at: start.addingTimeInterval(4))
        #expect(engine.status.phase == .onBreak)
        #expect(!engine.status.isPaused)
    }

    @Test func videoWhileIdleIsNotCreditedAsNaturalBreak() {
        var engine = engine()
        engine.send(.beginIdle(startedAt: start), at: start.addingTimeInterval(180))
        let effects = engine.send(.setProtection(meetingActive: false, videoActive: true), at: start.addingTimeInterval(200))
        #expect(engine.status.isVideoPaused)
        #expect(engine.completedBreaks == 0)
        #expect(!effects.contains { if case .persistSession(let record, _) = $0 { return record != nil }; return false })
    }

    @Test func restoredVideoPauseDoesNotStickWithoutPlayback() throws {
        var engine = engine()
        engine.send(.setProtection(meetingActive: false, videoActive: true), at: start)
        let state = try JSONDecoder().decode(SessionState.self, from: JSONEncoder().encode(engine.state))
        var restored = SessionEngine(configuration: engine.configuration, restoredState: state, now: start.addingTimeInterval(100))
        restored.send(.launch(meetingActive: false, videoActive: false), at: start.addingTimeInterval(100))
        #expect(!restored.status.isPaused)
    }

    @Test func audioGenericWakeLocksEditorsAndExcludedBrowsersDoNotTrigger() {
        let display = kIOPMAssertionTypePreventUserIdleDisplaySleep
        #expect(VideoDetectionPolicy.isVideoAssertion(type: display, name: "Video Wake Lock", level: 255))
        #expect(VideoDetectionPolicy.isVideoAssertion(type: display, name: "Playing video", level: 255))
        // Observed from Chrome via IOPMCopyAssertionsByProcess on macOS.
        #expect(VideoDetectionPolicy.isVideoAssertion(type: "NoDisplaySleepAssertion", name: "Video Wake Lock", level: 255))
        #expect(!VideoDetectionPolicy.isVideoAssertion(type: "NoDisplaySleepAssertion", name: "Playing audio", level: 255))
        #expect(!VideoDetectionPolicy.isVideoAssertion(type: "NoDisplaySleepAssertion", name: "Video Wake Lock", level: 0))
        #expect(!VideoDetectionPolicy.isVideoAssertion(type: "NoIdleSleepAssertion", name: "Video Wake Lock", level: 255))
        #expect(!VideoDetectionPolicy.isVideoAssertion(type: display, name: "Playing audio", level: 255))
        #expect(!VideoDetectionPolicy.isVideoAssertion(type: display, name: "Keep awake", level: 255))
        #expect(!VideoDetectionPolicy.isVideoAssertion(type: display, name: "Video Wake Lock", level: 0))
        #expect(!VideoDetectionPolicy.isVideoAssertion(type: kIOPMAssertionTypePreventUserIdleSystemSleep, name: "Video Wake Lock", level: 255))
        for id in ["com.spotify.client", "com.apple.Music", "com.apple.FinalCut", "com.blackmagic-design.DaVinciResolve", "com.apple.quicklook"] {
            #expect(!VideoDetectionPolicy.supports(bundleID: id, excludedBundleIDs: []))
        }
        #expect(!VideoDetectionPolicy.supports(bundleID: "com.google.Chrome", excludedBundleIDs: ["com.google.chrome"]))
    }

    @Test func safariRequiresItsOwnVisibleVideoAssertionAndRejectsAudio() {
        let name = "com.apple.WebCore: HTMLMediaElement playback"
        for id in ["com.apple.Safari", "com.apple.SafariTechnologyPreview"] {
            #expect(VideoDetectionPolicy.supports(bundleID: id, excludedBundleIDs: []))
            for type in [kIOPMAssertionTypePreventUserIdleDisplaySleep, "NoDisplaySleepAssertion"] {
                #expect(VideoDetectionPolicy.isVideoAssertion(type: type, name: name, level: 255, bundleID: id))
                #expect(!VideoDetectionPolicy.isVideoAssertion(type: type, name: name, level: 0, bundleID: id))
                #expect(!VideoDetectionPolicy.isVideoAssertion(type: type, name: "WebKit Media Playback", level: 255, bundleID: id))
            }
            #expect(!VideoDetectionPolicy.isVideoAssertion(type: kIOPMAssertionTypePreventUserIdleSystemSleep, name: name, level: 255, bundleID: id))
            #expect(!VideoDetectionPolicy.supports(bundleID: id, excludedBundleIDs: [id]))
        }
        #expect(!VideoDetectionPolicy.isVideoAssertion(type: kIOPMAssertionTypePreventUserIdleDisplaySleep, name: name, level: 255))
    }

    @Test func ignoreIsLimitedToTheCurrentFocusCycle() {
        var engine = engine()
        engine.send(.setProtection(meetingActive: true, videoActive: true), at: start)
        engine.send(.ignoreProtectionForCycle, at: start.addingTimeInterval(10))
        #expect(!engine.status.isPaused)
        engine.send(.setProtection(meetingActive: true, videoActive: true), at: start.addingTimeInterval(20))
        #expect(!engine.status.isPaused)
        engine.resetFocus(at: start.addingTimeInterval(30))
        engine.send(.setProtection(meetingActive: false, videoActive: true), at: start.addingTimeInterval(31))
        #expect(engine.status.isVideoPaused)
    }

    @Test func oldConfigurationAndSessionDataRemainCompatible() throws {
        let config = try JSONDecoder().decode(FocusConfiguration.self, from: Data("{\"focusDuration\":1800}".utf8))
        #expect(config.focusDuration == 1800)
        #expect(!config.meetingCameraDetectionEnabled)
        #expect(!config.meetingVirtualMicrophonesEnabled)
        let old = Data("{\"reason\":\"meeting\",\"awaySince\":0,\"meetingPending\":false,\"frozen\":{\"focus\":{\"remaining\":100,\"total\":1500,\"warningShown\":false}}}".utf8)
        let suspension = try JSONDecoder().decode(Suspension.self, from: old)
        #expect(suspension.videoPending == nil)
    }
}
