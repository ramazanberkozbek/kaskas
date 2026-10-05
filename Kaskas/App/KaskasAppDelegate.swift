import AppKit
import CoreGraphics
import SwiftData

@MainActor
final class KaskasAppDelegate: NSObject, NSApplicationDelegate {
    let sessionController: SessionController

    override init() {
        let sessionStore = SessionStore()
        let historyStore: BreakHistoryStore?
        let activityStore: ActivityStore?
        let appUsageStore: AppUsageStore?
        let excludedUsageStore: ExcludedUsageStore?
        do {
            let container = try ModelContainer(for: BreakRecord.self, ActivityRecord.self, AppUsageRecord.self, ExcludedUsageRecord.self)
            historyStore = BreakHistoryStore(container: container)
            activityStore = ActivityStore(container: container)
            appUsageStore = AppUsageStore(container: container)
            excludedUsageStore = ExcludedUsageStore(container: container)
        } catch {
            NSLog("Kaskas: Failed to open local history: %@", String(describing: error))
            historyStore = nil
            activityStore = nil
            appUsageStore = nil
            excludedUsageStore = nil
        }
        sessionController = SessionController(
            store: sessionStore,
            historyStore: historyStore,
            activityStore: activityStore,
            appUsageStore: appUsageStore,
            excludedUsageStore: excludedUsageStore
        )
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        SingleInstanceCoordinator.shared.enforceSingleInstance()
        sessionController.applyDockVisibility()

        #if !DEBUG
        sessionController.launchAtLogin.configureDefaultIfNeeded()
        #endif
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemClockDidChange(_:)),
            name: .NSSystemClockDidChange,
            object: nil
        )
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(
            self,
            selector: #selector(workspaceWillSleep(_:)),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(workspaceDidWake(_:)),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(screensDidSleep(_:)),
            name: NSWorkspace.screensDidSleepNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(screensDidWake(_:)),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(sessionDidResignActive(_:)),
            name: NSWorkspace.sessionDidResignActiveNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(sessionDidBecomeActive(_:)),
            name: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil
        )
        let distributed = DistributedNotificationCenter.default()
        // macOS broadcasts screen lock separately from display sleep and user switching.
        distributed.addObserver(self, selector: #selector(screenDidLock(_:)),
                                name: Notification.Name("com.apple.screenIsLocked"), object: nil)
        distributed.addObserver(self, selector: #selector(screenDidUnlock(_:)),
                                name: Notification.Name("com.apple.screenIsUnlocked"), object: nil)
        sessionController.start()
        if CGDisplayIsAsleep(CGMainDisplayID()) != 0 {
            updateAvailability(.screenSlept)
        }
        if let session = CGSessionCopyCurrentDictionary() as? [String: Any],
           session[kCGSessionOnConsoleKey as String] as? Bool == false {
            updateAvailability(.sessionResigned)
        }
        if ProcessInfo.processInfo.environment["KASKAS_OPEN_SETTINGS"] == "1" {
            sessionController.openSettings()
        }
    }

    private var availability = SessionAvailability()

    func applicationDidBecomeActive(_ notification: Notification) {
        sessionController.launchAtLogin.refresh()
        sessionController.reconcile()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        sessionController.openSettings()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // The session and menu bar must outlive the settings window.
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
        sessionController.stop()
    }

    @objc private func systemClockDidChange(_ notification: Notification) {
        sessionController.appUsage.clockDidChange(at: Date())
        sessionController.reconcile()
    }

    private func updateAvailability(_ event: SessionAvailability.Event) {
        switch availability.receive(event) {
        case .suspend:
            sessionController.systemWillSleep()
        case .resume:
            sessionController.systemDidWake()
        case nil:
            break
        }
    }

    @objc private func workspaceWillSleep(_ notification: Notification) {
        updateAvailability(.systemSlept)
    }

    @objc private func workspaceDidWake(_ notification: Notification) {
        // Sample the display before allowing a system wake to resume tracking.
        updateAvailability(CGDisplayIsAsleep(CGMainDisplayID()) != 0 ? .screenSlept : .screenWoke)
        updateAvailability(.systemWoke)
    }

    @objc private func screensDidSleep(_ notification: Notification) {
        updateAvailability(.screenSlept)
    }

    @objc private func screensDidWake(_ notification: Notification) {
        updateAvailability(.screenWoke)
    }

    @objc private func sessionDidResignActive(_ notification: Notification) {
        updateAvailability(.sessionResigned)
    }

    @objc private func sessionDidBecomeActive(_ notification: Notification) {
        updateAvailability(.sessionActivated)
    }

    @objc private func screenDidLock(_ notification: Notification) {
        updateAvailability(.screenLocked)
    }

    @objc private func screenDidUnlock(_ notification: Notification) {
        updateAvailability(.screenUnlocked)
    }
}

/// Resumes tracking only when the system, display, and unlocked user session are available.
struct SessionAvailability {
    enum Event {
        case systemSlept, systemWoke, screenSlept, screenWoke
        case sessionResigned, sessionActivated, screenLocked, screenUnlocked
    }

    enum Action: Equatable { case suspend, resume }

    private var systemAwake = true
    private var screenAwake = true
    private var sessionActive = true
    private var screenLocked = false

    var isAvailable: Bool { systemAwake && screenAwake && sessionActive && !screenLocked }

    mutating func receive(_ event: Event) -> Action? {
        let wasAvailable = isAvailable
        switch event {
        case .systemSlept: systemAwake = false
        case .systemWoke: systemAwake = true
        case .screenSlept: screenAwake = false
        case .screenWoke: screenAwake = true
        case .sessionResigned: sessionActive = false
        case .sessionActivated: sessionActive = true
        case .screenLocked: screenLocked = true
        case .screenUnlocked: screenLocked = false
        }
        guard wasAvailable != isAvailable else { return nil }
        return isAvailable ? .resume : .suspend
    }
}
