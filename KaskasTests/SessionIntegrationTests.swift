import AppKit
import Foundation
import Testing
@testable import Kaskas

@MainActor
struct SessionIntegrationTests {
    @Test
    func enablingDetectionDuringMeetingPausesImmediately() {
        let suiteName = "MeetingToggleTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SessionStore(defaults: defaults)
        var config = store.loadConfiguration()
        config.pauseDuringMeetings = false
        store.save(configuration: config)
        let monitor = ActiveMeetingMonitor()
        let controller = SessionController(store: store, meetingMonitor: monitor)
        config.pauseDuringMeetings = true
        controller.updateConfiguration(config)
        #expect(controller.sessionSnapshot.status.isMeetingPaused)
        monitor.stop()
    }

    @Test
    func wakeDoesNotResumeLockedOrInactiveSession() {
        var state = SessionAvailability()
        #expect(state.receive(.screenLocked) == .suspend)
        #expect(state.receive(.sessionResigned) == nil)
        #expect(state.receive(.systemSlept) == nil)
        #expect(state.receive(.screenSlept) == nil)
        #expect(state.receive(.systemWoke) == nil)
        #expect(state.receive(.screenWoke) == nil)
        #expect(state.receive(.screenUnlocked) == nil)
        #expect(!state.isAvailable)
        #expect(state.receive(.sessionActivated) == .resume)
        #expect(state.receive(.sessionActivated) == nil)
    }

    @Test
    func displayAndSystemWakeOrderDoesNotChangeResume() {
        for wakeEvents: [SessionAvailability.Event] in [[.systemWoke, .screenWoke], [.screenWoke, .systemWoke]] {
            var state = SessionAvailability()
            #expect(state.receive(.systemSlept) == .suspend)
            #expect(state.receive(.screenSlept) == nil)
            #expect(state.receive(wakeEvents[0]) == nil)
            #expect(state.receive(wakeEvents[1]) == .resume)
        }
    }

    @Test
    func wallpaperFailureKeepsPreviousFileAndSuccessCreatesPreparedRevision() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let source = directory.appendingPathComponent("source.png")
        let store = CustomWallpaperStore(directory: directory.appendingPathComponent("wallpapers"))
        try CustomWallpaperTests().writeImage(to: source, width: 128, height: 64)
        let saved = try await store.save(from: source)
        let firstBytes = try Data(contentsOf: saved.url)
        await #expect(throws: (any Error).self) {
            try await store.save(from: directory.appendingPathComponent("missing.png"))
        }
        #expect(try Data(contentsOf: saved.url) == firstBytes)
        try CustomWallpaperTests().writeImage(to: source, width: 64, height: 128)
        let replacement = try await store.save(from: source)
        #expect(replacement.url != saved.url)
        #expect(replacement.thumbnail.height == 128)
        #expect(try Data(contentsOf: saved.url) == firstBytes)
        // Selecting the existing wallpaper must not delete it before copying.
        let reselected = try await store.save(from: replacement.url)
        #expect(try Data(contentsOf: reselected.url) == Data(contentsOf: replacement.url))
        await store.removeOwnedFile(at: saved.url)
        await store.removeOwnedFile(at: replacement.url)
        #expect(try FileManager.default.contentsOfDirectory(atPath: reselected.url.deletingLastPathComponent().path) == [reselected.url.lastPathComponent])
    }

    @Test
    func instanceLockHasOneOwnerAndCanBeAcquiredAfterRelease() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var first: SingleInstanceFileLock? = SingleInstanceFileLock(directory: directory)
        let second = SingleInstanceFileLock(directory: directory)
        #expect(try first?.acquire(bundleID: "test.kaskas") == true)
        #expect(try first?.acquire(bundleID: "test.kaskas") == true)
        #expect(try !second.acquire(bundleID: "test.kaskas"))
        first = nil
        #expect(try second.acquire(bundleID: "test.kaskas"))
    }

    @Test
    func duplicateExitsEvenBeforeOwnerAppearsInWorkspace() {
        var exitCode: Int32?
        let coordinator = SingleInstanceCoordinator(
            runningInstancesProvider: { _ in [] },
            activationHandler: { _ in Issue.record("No process to activate") },
            lockAcquisition: { _ in false },
            exitHandler: { exitCode = $0 }
        )
        #expect(!coordinator.enforceSingleInstance(bundleID: "test.kaskas", currentPID: 42, isTestEnvironment: false))
        #expect(exitCode == 0)
    }

    @Test
    func screenTimeTodayReflectsActiveStudyingTime() {
        let suiteName = "ScreenTimeTodayTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SessionStore(defaults: defaults)
        let now = Date()
        let controller = SessionController(store: store, now: now)
        controller.start()

        let screenTimeAtStart = controller.screenTimeToday(at: now)
        #expect(screenTimeAtStart == 0)

        let tenMinutesLater = now.addingTimeInterval(10 * 60)
        let screenTimeLater = controller.screenTimeToday(at: tenMinutesLater)
        #expect(abs(screenTimeLater - 10 * 60) < 1.0)

        controller.stop()
    }
}

@MainActor
private final class ActiveMeetingMonitor: MeetingActivityMonitoring {
    func start(onChange: @escaping (Bool) -> Void) {}
    func stop() {}
    func sample() -> Bool { true }
}
