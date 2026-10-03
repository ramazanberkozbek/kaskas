import AppKit
import Darwin
import Foundation

@MainActor
final class SingleInstanceCoordinator {
    static let shared = SingleInstanceCoordinator()

    typealias RunningInstancesProvider = (String) -> [pid_t]
    typealias ExitHandler = (Int32) -> Void
    typealias ActivationHandler = (pid_t) -> Void
    typealias LockAcquisition = (String) throws -> Bool

    private let runningInstancesProvider: RunningInstancesProvider
    private let exitHandler: ExitHandler
    private let activationHandler: ActivationHandler
    private let acquireLock: LockAcquisition

    init(
        runningInstancesProvider: @escaping RunningInstancesProvider = { bundleID in
            NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                .filter { !$0.isTerminated }
                .map(\.processIdentifier)
        },
        activationHandler: @escaping ActivationHandler = { pid in
            NSRunningApplication(processIdentifier: pid)?.activate()
        },
        lockAcquisition: LockAcquisition? = nil,
        exitHandler: @escaping ExitHandler = { code in
            exit(code)
        }
    ) {
        let lock = SingleInstanceFileLock()
        acquireLock = lockAcquisition ?? { try lock.acquire(bundleID: $0) }
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

        do {
            if try acquireLock(bundleID) { return true }
        } catch {
            NSLog("Kaskas: Failed to acquire instance lock: %@", String(describing: error))
            exitHandler(1)
            return false
        }

        let runningPIDs = runningInstancesProvider(bundleID)
        let otherPIDs = runningPIDs.filter { $0 != currentPID }

        // The owner may not yet be registered with NSWorkspace during simultaneous launches.
        if let firstOtherPID = otherPIDs.first {
            activationHandler(firstOtherPID)
        }

        NSLog("Kaskas: Another instance holds the lock. Exiting duplicate.")
        exitHandler(0)
        return false
    }
}

/// Keeps the descriptor open for the owner's lifetime. The kernel releases the lock on exit.
final class SingleInstanceFileLock {
    private var descriptor: Int32 = -1
    private let directory: URL?

    init(directory: URL? = nil) {
        self.directory = directory
    }

    deinit {
        if descriptor >= 0 { close(descriptor) }
    }

    func acquire(bundleID: String) throws -> Bool {
        if descriptor >= 0 { return true }
        let directory = self.directory ?? FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0].appendingPathComponent(bundleID, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("instance.lock")
        let candidate = open(file.path, O_CREAT | O_RDWR | O_NOFOLLOW, mode_t(0o600))
        guard candidate >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        if flock(candidate, LOCK_EX | LOCK_NB) == 0 {
            descriptor = candidate
            return true
        }
        let error = errno
        close(candidate)
        if error == EWOULDBLOCK { return false }
        throw POSIXError(POSIXErrorCode(rawValue: error) ?? .EIO)
    }
}
