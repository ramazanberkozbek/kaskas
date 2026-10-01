import AppKit
import SwiftData

@MainActor
final class KaskasAppDelegate: NSObject, NSApplicationDelegate {
    let sessionController: SessionController

    override init() {
        let sessionStore = SessionStore()
        let historyStore: BreakHistoryStore?
        let activityStore: ActivityStore?
        let appUsageStore: AppUsageStore?
        do {
            let container = try ModelContainer(for: BreakRecord.self, ActivityRecord.self, AppUsageRecord.self)
            historyStore = BreakHistoryStore(container: container)
            activityStore = ActivityStore(container: container)
            appUsageStore = AppUsageStore(container: container)
        } catch {
            NSLog("Kaskas: Failed to open local history: %@", String(describing: error))
            historyStore = nil
            activityStore = nil
            appUsageStore = nil
        }
        if let historyStore {
            do {
                try historyStore.importLegacyRecords(from: sessionStore)
            } catch {
                NSLog("Kaskas: Failed to import old break history: %@", String(describing: error))
            }
        }
        sessionController = SessionController(
            store: sessionStore,
            historyStore: historyStore,
            activityStore: activityStore,
            appUsageStore: appUsageStore
        )
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        SingleInstanceCoordinator.shared.enforceSingleInstance()

        #if !DEBUG
        sessionController.launchAtLogin.configureDefaultIfNeeded()
        #endif
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemClockDidChange(_:)),
            name: .NSSystemClockDidChange,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceWillSleep(_:)),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceDidWake(_:)),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        sessionController.start()
        if ProcessInfo.processInfo.environment["KASKAS_OPEN_SETTINGS"] == "1" {
            sessionController.openSettings()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        sessionController.launchAtLogin.refresh()
        sessionController.reconcile()
    }

    func applicationWillTerminate(_ notification: Notification) {
        sessionController.stop()
    }

    @objc private func systemClockDidChange(_ notification: Notification) {
        sessionController.appUsage.clockDidChange(at: Date())
        sessionController.reconcile()
    }

    @objc private func workspaceWillSleep(_ notification: Notification) {
        sessionController.systemWillSleep()
    }

    @objc private func workspaceDidWake(_ notification: Notification) {
        sessionController.systemDidWake()
    }
}
