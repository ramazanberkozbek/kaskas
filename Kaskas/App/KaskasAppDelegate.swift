import AppKit

@MainActor
final class KaskasAppDelegate: NSObject, NSApplicationDelegate {
    let sessionController = SessionController()

    func applicationDidFinishLaunching(_ notification: Notification) {
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
