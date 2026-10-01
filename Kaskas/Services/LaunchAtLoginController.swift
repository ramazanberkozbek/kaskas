import Foundation
import Observation
import ServiceManagement

@MainActor
protocol LaunchAtLoginService {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
    func openSystemSettings()
}

@MainActor
private struct MainAppLoginService: LaunchAtLoginService {
    var status: SMAppService.Status { SMAppService.mainApp.status }

    func register() throws { try SMAppService.mainApp.register() }
    func unregister() throws { try SMAppService.mainApp.unregister() }
    func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}

@MainActor
@Observable
final class LaunchAtLoginController {
    private static let initializedKey = "kaskas_launch_at_login_initialized"

    private(set) var status: SMAppService.Status
    private(set) var updateFailed = false

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let service: any LaunchAtLoginService

    init(defaults: UserDefaults = .standard, service: (any LaunchAtLoginService)? = nil) {
        self.defaults = defaults
        let service = service ?? MainAppLoginService()
        self.service = service
        status = service.status
    }

    var isEnabled: Bool { status == .enabled }
    var requiresApproval: Bool { status == .requiresApproval }

    func configureDefaultIfNeeded() {
        refresh()
        guard !defaults.bool(forKey: Self.initializedKey) else { return }
        // Apply the default once, then respect changes made in either settings UI.
        if status == .enabled || status == .requiresApproval {
            defaults.set(true, forKey: Self.initializedKey)
        } else {
            setEnabled(true)
        }
    }

    func refresh() {
        status = service.status
    }

    func setEnabled(_ enabled: Bool) {
        refresh()
        updateFailed = false
        do {
            if enabled {
                if requiresApproval {
                    openSystemSettings()
                } else if !isEnabled {
                    try service.register()
                }
            } else if isEnabled || requiresApproval {
                try service.unregister()
            }
            defaults.set(true, forKey: Self.initializedKey)
        } catch {
            updateFailed = true
            NSLog("Kaskas: Failed to update launch at login: %@", String(describing: error))
        }
        refresh()
    }

    func openSystemSettings() {
        service.openSystemSettings()
    }
}
