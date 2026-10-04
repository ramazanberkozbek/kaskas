import CoreAudio
import Foundation
import Synchronization
import Testing
@testable import Kaskas

@MainActor
struct MeetingActivityMonitorTests {
    @Test
    func cachedSamplesNeverAccessHardwareAndStartupPublishesOnMainActor() async throws {
        let hardware = FakeMeetingHardware()
        hardware.state.withLock { $0.active = true }
        let monitor = MeetingActivityMonitor(worker: worker(hardware))
        var changes: [Bool] = []
        #expect(!monitor.sample())
        #expect(hardware.snapshot.probes == 0)
        monitor.start {
            #expect(Thread.isMainThread)
            changes.append($0)
        }
        #expect(!monitor.sample())
        #expect(hardware.snapshot.probes == 0)
        try await waitUntil { changes == [true] }
        for _ in 0..<100 { #expect(monitor.sample()) }
        #expect(hardware.snapshot.probes == 1)
        #expect(hardware.snapshot.allOperationsOffMain)
        monitor.stop()
        try await waitUntil { hardware.snapshot.stops == 1 }
        #expect(monitor.sample())
        #expect(hardware.snapshot.probes == 1)
    }

    @Test
    func listenerBurstsUseCachedInventoryAndDeviceChangesRediscover() async throws {
        let hardware = FakeMeetingHardware()
        let monitor = MeetingActivityMonitor(worker: worker(hardware))
        var changes: [Bool] = []
        monitor.start { changes.append($0) }
        try await waitUntil { hardware.snapshot.probes == 1 }
        hardware.state.withLock { $0.active = true }
        for _ in 0..<100 { hardware.notify(inventoryChanged: false) }
        try await waitUntil { changes == [true] }
        #expect(hardware.snapshot.probes == 2)
        #expect(hardware.snapshot.discoveries == 1)
        #expect(hardware.snapshot.listenerSynchronizations == 1)

        hardware.state.withLock { $0.inputs = [2, 3] }
        for _ in 0..<100 { hardware.notify(inventoryChanged: true) }
        try await waitUntil { hardware.snapshot.probes == 3 }
        #expect(hardware.snapshot.discoveries == 2)
        #expect(hardware.snapshot.lastProbedInputs == [2, 3])
        #expect(hardware.snapshot.listenerSynchronizations == 2)
        #expect(changes == [true])
        hardware.state.withLock { $0.active = false }
        hardware.notify(inventoryChanged: false)
        try await waitUntil { changes == [true, false] }
        #expect(hardware.snapshot.discoveries == 2)
        #expect(hardware.snapshot.allOperationsOffMain)
        monitor.stop()
        try await waitUntil { hardware.snapshot.stops == 1 }
    }

    @Test
    func periodicPollingUsesCachedInventoryAndStops() async throws {
        let hardware = FakeMeetingHardware()
        let monitor = MeetingActivityMonitor(worker: worker(hardware, pollInterval: .milliseconds(30)))
        monitor.start { _ in }
        try await waitUntil { hardware.snapshot.probes >= 3 }
        #expect(hardware.snapshot.discoveries == 1)
        #expect(hardware.snapshot.listenerSynchronizations == 1)
        #expect(hardware.snapshot.allOperationsOffMain)
        monitor.stop()
        try await waitUntil { hardware.snapshot.stops == 1 }
        let probes = hardware.snapshot.probes
        try await Task.sleep(for: .milliseconds(100))
        #expect(hardware.snapshot.probes == probes)
    }

    @Test
    func restartRejectsOldListenerCallbacksAndCancelsPendingRefresh() async throws {
        let hardware = FakeMeetingHardware()
        let monitor = MeetingActivityMonitor(worker: worker(hardware))
        var firstChanges: [Bool] = []
        var newChanges: [Bool] = []
        monitor.start { firstChanges.append($0) }
        try await waitUntil { hardware.snapshot.probes == 1 }
        let oldCallback = try #require(hardware.snapshot.callback)
        hardware.notify(inventoryChanged: true)
        monitor.stop()
        hardware.state.withLock { $0.active = true }
        monitor.start { newChanges.append($0) }
        try await waitUntil { newChanges == [true] }
        let probes = hardware.snapshot.probes
        let discoveries = hardware.snapshot.discoveries
        for _ in 0..<100 { oldCallback(true) }
        try await Task.sleep(for: .milliseconds(100))
        #expect(firstChanges.isEmpty)
        #expect(newChanges == [true])
        #expect(hardware.snapshot.probes == probes)
        #expect(hardware.snapshot.discoveries == discoveries)
        #expect(hardware.snapshot.stops == 1)
        monitor.stop()
        try await waitUntil { hardware.snapshot.stops == 2 }
    }

    @Test
    func failedDeviceListListenerRetriesDiscoveryDuringPolling() async throws {
        let hardware = FakeMeetingHardware()
        hardware.state.withLock { $0.deviceListListenerInstalled = false }
        let monitor = MeetingActivityMonitor(worker: worker(hardware, pollInterval: .milliseconds(30)))
        monitor.start { _ in }
        try await waitUntil { hardware.snapshot.discoveries >= 2 }
        hardware.state.withLock { $0.deviceListListenerInstalled = true }
        try await waitUntil { hardware.snapshot.successfulSynchronizations >= 1 }
        let discoveries = hardware.snapshot.discoveries
        let probes = hardware.snapshot.probes
        try await waitUntil { hardware.snapshot.probes >= probes + 2 }
        #expect(hardware.snapshot.discoveries == discoveries)
        monitor.stop()
        try await waitUntil { hardware.snapshot.stops == 1 }
    }

    @Test
    func releasingMonitorTearsDownWorkerListeners() async throws {
        let hardware = FakeMeetingHardware()
        var monitor: MeetingActivityMonitor? = MeetingActivityMonitor(worker: worker(hardware))
        weak var weakMonitor = monitor
        monitor?.start { _ in }
        try await waitUntil { hardware.snapshot.probes == 1 }
        monitor = nil
        #expect(weakMonitor == nil)
        try await waitUntil { hardware.snapshot.stops == 1 }
        #expect(hardware.snapshot.callback == nil)
        #expect(hardware.snapshot.allOperationsOffMain)
    }

    private func worker(_ hardware: FakeMeetingHardware, pollInterval: Duration = .seconds(3600)) -> MeetingActivityWorker {
        MeetingActivityWorker(pollInterval: pollInterval, coalescingInterval: .milliseconds(40)) { hardware }
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while !condition(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(condition())
    }
}

nonisolated private final class FakeMeetingHardware: MeetingActivityHardware, Sendable {
    struct State: Sendable {
        var active = false
        var inputs: [AudioDeviceID] = [1]
        var lastProbedInputs: [AudioDeviceID] = []
        var discoveries = 0
        var probes = 0
        var listenerSynchronizations = 0
        var successfulSynchronizations = 0
        var stops = 0
        var allOperationsOffMain = true
        var deviceListListenerInstalled = true
        var callback: (@Sendable (Bool) -> Void)?
        var queue: DispatchQueue?
    }

    let state = Mutex(State())
    var snapshot: State { state.withLock { $0 } }

    func inputDevices() -> [AudioDeviceID] {
        state.withLock {
            $0.allOperationsOffMain = $0.allOperationsOffMain && !Thread.isMainThread
            if let queue = $0.queue { dispatchPrecondition(condition: .onQueue(queue)) }
            $0.discoveries += 1
            return $0.inputs
        }
    }

    func isActive(inputs: [AudioDeviceID]) -> Bool {
        state.withLock {
            $0.allOperationsOffMain = $0.allOperationsOffMain && !Thread.isMainThread
            if let queue = $0.queue { dispatchPrecondition(condition: .onQueue(queue)) }
            $0.probes += 1
            $0.lastProbedInputs = inputs
            return $0.active
        }
    }

    func synchronizeListeners(
        inputs: Set<AudioDeviceID>, queue: DispatchQueue,
        onChange: @escaping @Sendable (Bool) -> Void
    ) -> Bool {
        dispatchPrecondition(condition: .onQueue(queue))
        return state.withLock {
            $0.allOperationsOffMain = $0.allOperationsOffMain && !Thread.isMainThread
            $0.listenerSynchronizations += 1
            if $0.deviceListListenerInstalled {
                $0.successfulSynchronizations += 1
            }
            $0.queue = queue
            $0.callback = onChange
            return $0.deviceListListenerInstalled
        }
    }

    func stop() {
        state.withLock {
            $0.allOperationsOffMain = $0.allOperationsOffMain && !Thread.isMainThread
            if let queue = $0.queue { dispatchPrecondition(condition: .onQueue(queue)) }
            $0.stops += 1
            $0.callback = nil
        }
    }

    func notify(inventoryChanged: Bool) { snapshot.callback?(inventoryChanged) }
}
