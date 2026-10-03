import AppKit

@MainActor
protocol ForegroundAppMonitoring: AnyObject {
    func start(onChange: @escaping (ForegroundApp?) -> Void)
    func stop()
    func sample() -> ForegroundApp?
}

/// App identity only: no Accessibility, Apple Events, window titles, or polling timer.
@MainActor
final class ForegroundAppMonitor: NSObject, ForegroundAppMonitoring {
    private let workspace: NSWorkspace
    private var onChange: ((ForegroundApp?) -> Void)?
    private var sessionActive = true
    private var screensAwake = true

    init(workspace: NSWorkspace = .shared) { self.workspace = workspace }

    func start(onChange: @escaping (ForegroundApp?) -> Void) {
        stop()
        self.onChange = onChange
        sessionActive = true
        screensAwake = true
        let center = workspace.notificationCenter
        center.addObserver(self, selector: #selector(activated(_:)), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        center.addObserver(self, selector: #selector(sessionLeft), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        center.addObserver(self, selector: #selector(sessionReturned), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        center.addObserver(self, selector: #selector(screensSlept), name: NSWorkspace.screensDidSleepNotification, object: nil)
        center.addObserver(self, selector: #selector(screensWoke), name: NSWorkspace.screensDidWakeNotification, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(kaskasActiveChanged), name: NSApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(kaskasActiveChanged), name: NSApplication.didResignActiveNotification, object: nil)

        onChange(sample())
    }

    func stop() {
        workspace.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
        onChange = nil
    }

    func sample() -> ForegroundApp? {
        guard sessionActive, screensAwake else { return nil }
        if NSRunningApplication.current.isActive {
            return identity(NSRunningApplication.current)
        }
        guard let app = workspace.frontmostApplication else { return nil }
        return identity(app)
    }

    private func identity(_ app: NSRunningApplication) -> ForegroundApp? {
        let isKaskas = (app.bundleIdentifier != nil && app.bundleIdentifier == Bundle.main.bundleIdentifier) || app == NSRunningApplication.current
        guard isKaskas || app.activationPolicy == .regular,
              let name = app.localizedName ?? (isKaskas ? "Kaskas" : nil) else { return nil }
        return ForegroundApp(bundleID: app.bundleIdentifier, name: name)
    }

    @objc private func activated(_ notification: Notification) {
        guard sessionActive, screensAwake, let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        onChange?(identity(app))
    }
    @objc private func kaskasActiveChanged() {
        guard sessionActive, screensAwake else { return }
        onChange?(sample())
    }
    @objc private func sessionLeft() { sessionActive = false; onChange?(nil) }
    @objc private func sessionReturned() { sessionActive = true; onChange?(sample()) }
    @objc private func screensSlept() { screensAwake = false; onChange?(nil) }
    @objc private func screensWoke() { screensAwake = true; onChange?(sample()) }
}
