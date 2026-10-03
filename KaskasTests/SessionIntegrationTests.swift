import Foundation
import Testing
@testable import Kaskas

@MainActor
struct SessionIntegrationTests {
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
}
