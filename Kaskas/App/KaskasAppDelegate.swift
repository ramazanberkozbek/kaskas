import AppKit

@MainActor
final class KaskasAppDelegate: NSObject, NSApplicationDelegate {
    let sessionController: SessionController
    private let startupError: Error?

    override init() {
        let sessionStore = SessionStore()
        do {
            let historyStore = try BreakHistoryStore()
            try historyStore.importLegacyRecords(from: sessionStore)
            sessionController = SessionController(store: sessionStore, historyStore: historyStore)
            startupError = nil
        } catch {
            sessionController = SessionController(store: sessionStore)
            startupError = error
        }
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let startupError {
            NSLog("Kaskas: Failed to open break history: %@", String(describing: startupError))
            let alert = NSAlert()
            alert.messageText = String(localized: "persistence.error.title")
            alert.informativeText = String(localized: "persistence.error.message")
            alert.runModal()
            NSApp.terminate(nil)
            return
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemClockDidChange(_:)),
            name: .NSSystemClockDidChange,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceDidWake(_:)),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        sessionController.start()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        sessionController.reconcile()
    }

    func applicationWillTerminate(_ notification: Notification) {
        sessionController.stop()
    }

    @objc private func systemClockDidChange(_ notification: Notification) {
        sessionController.reconcile()
    }

    @objc private func workspaceDidWake(_ notification: Notification) {
        sessionController.reconcile()
    }
}
