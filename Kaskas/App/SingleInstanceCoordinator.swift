import AppKit
import Foundation

@MainActor
final class SingleInstanceCoordinator {
    static let shared = SingleInstanceCoordinator()

    typealias RunningInstancesProvider = (String) -> [pid_t]
    typealias ExitHandler = (Int32) -> Void
    typealias ActivationHandler = (pid_t) -> Void

    private let runningInstancesProvider: RunningInstancesProvider
    private let exitHandler: ExitHandler
    private let activationHandler: ActivationHandler

    init(
        runningInstancesProvider: @escaping RunningInstancesProvider = { bundleID in
            NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                .filter { !$0.isTerminated }
                .map(\.processIdentifier)
        },
        activationHandler: @escaping ActivationHandler = { pid in
            NSRunningApplication(processIdentifier: pid)?.activate()
        },
        exitHandler: @escaping ExitHandler = { code in
            exit(code)
        }
    ) {
        self.runningInstancesProvider = runningInstancesProvider
        self.activationHandler = activationHandler
        self.exitHandler = exitHandler
    }

    @discardableResult
    func enforceSingleInstance(
        bundleID: String? = Bundle.main.bundleIdentifier,
        currentPID: pid_t = ProcessInfo.processInfo.processIdentifier,
        isTestEnvironment: Bool = (
            ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
            ProcessInfo.processInfo.environment["XCInjectBundleInto"] != nil ||
            NSClassFromString("XCTestCase") != nil
        )
    ) -> Bool {
        if isTestEnvironment {
            return true
        }

        guard let bundleID else { return true }

        let runningPIDs = runningInstancesProvider(bundleID)
        let otherPIDs = runningPIDs.filter { $0 != currentPID }

        guard let firstOtherPID = otherPIDs.first else { return true }

        NSLog("Kaskas: Another instance (PID: %d) is already running. Activating existing instance and exiting duplicate.", firstOtherPID)
        activationHandler(firstOtherPID)
        exitHandler(0)
        return false
    }
}
