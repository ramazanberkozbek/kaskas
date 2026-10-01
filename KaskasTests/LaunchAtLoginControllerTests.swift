import Foundation
import ServiceManagement
import Testing
@testable import Kaskas

@MainActor
struct LaunchAtLoginControllerTests {
    @Test
    func firstLaunchEnablesAutomaticStartupOnlyOnce() {
        withDefaults { defaults in
            let service = FakeLoginService()
            let controller = LaunchAtLoginController(defaults: defaults, service: service)
            controller.configureDefaultIfNeeded()
            controller.configureDefaultIfNeeded()

            #expect(controller.isEnabled)
            #expect(service.registrationCount == 1)
        }
    }

    @Test
    func disablingPersistsAcrossRelaunchAndCanBeEnabledAgain() {
        withDefaults { defaults in
            let service = FakeLoginService()
            let controller = LaunchAtLoginController(defaults: defaults, service: service)
            controller.configureDefaultIfNeeded()
            controller.setEnabled(false)

            let relaunched = LaunchAtLoginController(defaults: defaults, service: service)
            relaunched.configureDefaultIfNeeded()
            #expect(!relaunched.isEnabled)
            #expect(service.registrationCount == 1)
            #expect(service.unregistrationCount == 1)

            relaunched.setEnabled(true)
            #expect(relaunched.isEnabled)
            #expect(service.registrationCount == 2)
        }
    }

    @Test
    func disablingBeforeDefaultSetupIsRespected() {
        withDefaults { defaults in
            let service = FakeLoginService()
            let controller = LaunchAtLoginController(defaults: defaults, service: service)
            controller.setEnabled(false)
            controller.configureDefaultIfNeeded()

            #expect(!controller.isEnabled)
            #expect(service.registrationCount == 0)
            #expect(service.unregistrationCount == 0)
        }
    }

    @Test
    func changesInSystemSettingsAreReflectedAndNeverOverridden() {
        withDefaults { defaults in
            let service = FakeLoginService()
            let controller = LaunchAtLoginController(defaults: defaults, service: service)
            controller.configureDefaultIfNeeded()
            service.status = .requiresApproval
            controller.refresh()
            #expect(!controller.isEnabled)
            #expect(controller.requiresApproval)

            service.status = .notRegistered
            let relaunched = LaunchAtLoginController(defaults: defaults, service: service)
            relaunched.configureDefaultIfNeeded()
            #expect(!relaunched.isEnabled)
            #expect(service.registrationCount == 1)
        }
    }

    @Test(arguments: [SMAppService.Status.enabled, .requiresApproval])
    func existingRegistrationIsPreserved(status: SMAppService.Status) {
        withDefaults { defaults in
            let service = FakeLoginService()
            service.status = status
            let controller = LaunchAtLoginController(defaults: defaults, service: service)
            controller.configureDefaultIfNeeded()

            #expect(controller.status == status)
            #expect(service.registrationCount == 0)
            #expect(service.openSettingsCount == 0)
        }
    }

    @Test
    func pendingApprovalIsShownWithoutClaimingStartupIsEnabled() {
        withDefaults { defaults in
            let service = FakeLoginService()
            service.registrationStatus = .requiresApproval
            let controller = LaunchAtLoginController(defaults: defaults, service: service)
            controller.configureDefaultIfNeeded()

            #expect(!controller.isEnabled)
            #expect(controller.requiresApproval)
            #expect(service.openSettingsCount == 0)
            controller.setEnabled(true)
            #expect(service.openSettingsCount == 1)
            #expect(service.registrationCount == 1)

            controller.setEnabled(false)
            #expect(!controller.requiresApproval)
            #expect(service.unregistrationCount == 1)
        }
    }

    @Test
    func registrationFailureKeepsActualStatusAndAllowsRetry() {
        withDefaults { defaults in
            let service = FakeLoginService()
            service.shouldFail = true
            let controller = LaunchAtLoginController(defaults: defaults, service: service)
            controller.configureDefaultIfNeeded()

            #expect(!controller.isEnabled)
            #expect(controller.updateFailed)

            service.shouldFail = false
            controller.configureDefaultIfNeeded()
            #expect(controller.isEnabled)
            #expect(!controller.updateFailed)
            #expect(service.registrationCount == 2)
        }
    }

    @Test
    func unregistrationFailureKeepsToggleEnabledAndAllowsRetry() {
        withDefaults { defaults in
            let service = FakeLoginService()
            let controller = LaunchAtLoginController(defaults: defaults, service: service)
            controller.configureDefaultIfNeeded()
            service.shouldFail = true
            controller.setEnabled(false)

            #expect(controller.isEnabled)
            #expect(controller.updateFailed)

            service.shouldFail = false
            controller.setEnabled(false)
            #expect(!controller.isEnabled)
            #expect(!controller.updateFailed)
        }
    }

    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let suiteName = "test_launch_at_login_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        body(defaults)
    }
}

@MainActor
private final class FakeLoginService: LaunchAtLoginService {
    var status: SMAppService.Status = .notRegistered
    var registrationStatus: SMAppService.Status = .enabled
    var registrationCount = 0
    var unregistrationCount = 0
    var openSettingsCount = 0
    var shouldFail = false

    func register() throws {
        registrationCount += 1
        if shouldFail { throw CocoaError(.fileWriteNoPermission) }
        status = registrationStatus
    }

    func unregister() throws {
        unregistrationCount += 1
        if shouldFail { throw CocoaError(.fileWriteNoPermission) }
        status = .notRegistered
    }

    func openSystemSettings() {
        openSettingsCount += 1
    }
}
