import Foundation
import Testing
@testable import Kaskas

@MainActor
struct SingleInstanceCoordinatorTests {
    @Test
    func allowsFirstInstanceToRunWhenNoDuplicatesExist() {
        var activatedPID: pid_t?
        var exitCode: Int32?

        let coordinator = SingleInstanceCoordinator(
            runningInstancesProvider: { _ in [100] },
            activationHandler: { pid in activatedPID = pid },
            exitHandler: { code in exitCode = code }
        )

        let canProceed = coordinator.enforceSingleInstance(
            bundleID: "com.ramazanozbek.kaskas",
            currentPID: 100,
            isTestEnvironment: false
        )

        #expect(canProceed)
        #expect(activatedPID == nil)
        #expect(exitCode == nil)
    }

    @Test
    func terminatesDuplicateAndActivatesExistingInstance() {
        var activatedPID: pid_t?
        var exitCode: Int32?

        let coordinator = SingleInstanceCoordinator(
            runningInstancesProvider: { _ in [100, 200] },
            activationHandler: { pid in activatedPID = pid },
            exitHandler: { code in exitCode = code }
        )

        let canProceed = coordinator.enforceSingleInstance(
            bundleID: "com.ramazanozbek.kaskas",
            currentPID: 200,
            isTestEnvironment: false
        )

        #expect(!canProceed)
        #expect(activatedPID == 100)
        #expect(exitCode == 0)
    }

    @Test
    func bypassesCheckInTestEnvironment() {
        var exitCode: Int32?

        let coordinator = SingleInstanceCoordinator(
            runningInstancesProvider: { _ in [100, 200] },
            activationHandler: { _ in },
            exitHandler: { code in exitCode = code }
        )

        let canProceed = coordinator.enforceSingleInstance(
            bundleID: "com.ramazanozbek.kaskas",
            currentPID: 200,
            isTestEnvironment: true
        )

        #expect(canProceed)
        #expect(exitCode == nil)
    }

    @Test
    func handlesMissingBundleIdentifierGracefully() {
        var exitCode: Int32?

        let coordinator = SingleInstanceCoordinator(
            runningInstancesProvider: { _ in [100] },
            activationHandler: { _ in },
            exitHandler: { code in exitCode = code }
        )

        let canProceed = coordinator.enforceSingleInstance(
            bundleID: nil,
            currentPID: 100,
            isTestEnvironment: false
        )

        #expect(canProceed)
        #expect(exitCode == nil)
    }
}
