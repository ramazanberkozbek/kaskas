import AVFoundation
import CoreAudio
import Foundation

@MainActor
// Contributor note: meeting detection is app-independent microphone activity,
// not a Zoom/Teams/Meet allowlist or a guarantee that a call is in progress.
// Calls in those apps can qualify while an eligible input process/device is active;
// an open app, muted/listen-only call or camera-only call may not qualify.
// Camera detection and virtual microphones are separate opt-ins. Application
// exclusions currently cover microphone attribution; cameras use device exclusions.
// For a missed call, report app/macOS versions, input device transport and the
// attributed Core Audio process/device match before adding app-specific logic.
// Validate connect/disconnect, sleep/wake, mute/unmute, exclusions and teardown.
// Keep device discovery off the main actor.
protocol MeetingActivityMonitoring {
    func start(onChange: @escaping (Bool) -> Void)
    func stop()
    func sample() -> Bool
    func configure(_ options: MeetingDetectionOptions)
    func availableDevices() async -> [MeetingInputDevice]
}

extension MeetingActivityMonitoring {
    func configure(_ options: MeetingDetectionOptions) {}
    func availableDevices() async -> [MeetingInputDevice] { [] }
}

nonisolated struct MeetingDetectionOptions: Equatable, Sendable {
    var cameraEnabled = false
    var virtualMicrophonesEnabled = false
    var excludedBundleIDs: [String] = []
    var excludedDeviceUIDs: [String] = []
}


nonisolated struct MeetingInputDevice: Identifiable, Sendable {
    let id: String
    let name: String
}

/// UI-facing cache. Hardware access belongs exclusively to the worker's serial executor.
@MainActor
final class MeetingActivityMonitor: MeetingActivityMonitoring {
    private let worker: MeetingActivityWorker
    private var lifecycleTask: Task<Void, Never>?
    private var generation = UUID()
    private var lastSample = false
    private var lastRevision: UInt64 = 0
    private var onChange: ((Bool) -> Void)?
    private var options = MeetingDetectionOptions()

    init(worker: MeetingActivityWorker = MeetingActivityWorker()) {
        self.worker = worker
    }

    deinit {
        let previous = lifecycleTask
        let worker = worker
        Task {
            await previous?.value
            await worker.stop()
        }
    }

    func start(onChange: @escaping (Bool) -> Void) {
        generation = UUID()
        let generation = generation
        self.onChange = onChange
        lastSample = false
        lastRevision = 0
        let previous = lifecycleTask
        let worker = worker
        let initialSample = lastSample
        let options = options
        lifecycleTask = Task { [weak self] in
            await previous?.value
            await worker.start(generation: generation, initialSample: initialSample, options: options) { [weak self] active, revision in
                guard let self, self.generation == generation, self.onChange != nil else { return }
                guard revision > self.lastRevision else { return }
                self.lastRevision = revision
                guard active != self.lastSample else { return }
                self.lastSample = active
                self.onChange?(active)
            }
        }
    }

    func availableDevices() async -> [MeetingInputDevice] { await worker.availableDevices() }

    func configure(_ options: MeetingDetectionOptions) {
        guard self.options != options else { return }
        self.options = options
        if let onChange { start(onChange: onChange) }
    }

    func stop() {
        generation = UUID()
        onChange = nil
        let previous = lifecycleTask
        let worker = worker
        lifecycleTask = Task {
            await previous?.value
            await worker.stop()
        }
    }

    /// Always cached, including before startup and after teardown; never probes from a getter.
    func sample() -> Bool { lastSample }
}

/// Synchronous hardware operations are created and used only on the worker executor.
nonisolated protocol MeetingActivityHardware {
    func inputDevices() -> [AudioDeviceID]
    func isActive(inputs: [AudioDeviceID]) -> Bool
    func synchronizeListeners(
        inputs: Set<AudioDeviceID>, queue: DispatchQueue,
        onChange: @escaping @Sendable (_ inventoryChanged: Bool) -> Void
    ) -> Bool
    func stop()
    func configure(_ options: MeetingDetectionOptions)
}

nonisolated extension MeetingActivityHardware {
    func configure(_ options: MeetingDetectionOptions) {}
}

actor MeetingActivityWorker {
    nonisolated let queue = DispatchSerialQueue(label: "com.kaskas.meeting-hardware", qos: .utility)
    nonisolated var unownedExecutor: UnownedSerialExecutor { queue.asUnownedSerialExecutor() }

    private let makeHardware: @Sendable () -> any MeetingActivityHardware
    private let pollInterval: Duration
    private let coalescingInterval: Duration
    private var hardware: (any MeetingActivityHardware)?
    private var inputs: [AudioDeviceID] = []
    private var observesDeviceList = false
    private var inventoryDirty = false
    private var generation: UUID?
    private var lastSample = false
    private var revision: UInt64 = 0
    private var publish: (@MainActor @Sendable (Bool, UInt64) -> Void)?
    private var pollingTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?

    init(
        pollInterval: Duration = .seconds(2),
        coalescingInterval: Duration = .milliseconds(100),
        makeHardware: @escaping @Sendable () -> any MeetingActivityHardware = { CoreMeetingActivityHardware() }
    ) {
        self.pollInterval = pollInterval
        self.coalescingInterval = coalescingInterval
        self.makeHardware = makeHardware
    }

    func availableDevices() -> [MeetingInputDevice] {
        // Explicit settings read, not a render-time getter or polling operation.
        CoreMeetingActivityHardware().availableDevices()
    }

    func start(
        generation: UUID, initialSample: Bool, options: MeetingDetectionOptions = MeetingDetectionOptions(),
        publish: @escaping @MainActor @Sendable (Bool, UInt64) -> Void
    ) {
        stop()
        self.generation = generation
        self.lastSample = initialSample
        revision = 0
        self.publish = publish
        hardware = makeHardware()
        hardware?.configure(options)
        inventoryDirty = true
        refresh(generation: generation)
        let interval = pollInterval
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: interval) } catch { return }
                guard let self else { return }
                await self.refresh(generation: generation)
            }
        }
    }

    func stop() {
        generation = nil
        pollingTask?.cancel()
        pollingTask = nil
        refreshTask?.cancel()
        refreshTask = nil
        publish = nil
        hardware?.stop()
        hardware = nil
        inputs = []
        observesDeviceList = false
        inventoryDirty = false
    }

    func requestRefresh(inventoryChanged: Bool, generation: UUID) {
        guard self.generation == generation else { return }
        inventoryDirty = inventoryDirty || inventoryChanged
        guard refreshTask == nil else { return }
        let interval = coalescingInterval
        refreshTask = Task { [weak self] in
            do { try await Task.sleep(for: interval) } catch { return }
            await self?.finishRefresh(generation: generation)
        }
    }

    private func finishRefresh(generation: UUID) {
        guard self.generation == generation else { return }
        refreshTask = nil
        refresh(generation: generation)
    }

    private func refresh(generation: UUID) {
        guard self.generation == generation, let hardware else { return }
        // If device-list registration failed, polling also retries discovery/registration.
        if inventoryDirty || !observesDeviceList {
            inventoryDirty = false
            inputs = hardware.inputDevices()
            observesDeviceList = hardware.synchronizeListeners(inputs: Set(inputs), queue: queue) { [weak self] changed in
                Task { await self?.requestRefresh(inventoryChanged: changed, generation: generation) }
            }
        }
        let active = hardware.isActive(inputs: inputs)
        guard active != lastSample, let publish else { return }
        lastSample = active
        revision += 1
        let revision = revision
        Task { @MainActor in publish(active, revision) }
    }
}

/// This non-Sendable instance never leaves the worker. Listener blocks only enqueue actor work.
nonisolated private final class CoreMeetingActivityHardware: MeetingActivityHardware {
    private var observedInputs = Set<AudioDeviceID>()
    private var observesDeviceList = false
    private var deviceListListener: AudioObjectPropertyListenerBlock?
    private var runningListener: AudioObjectPropertyListenerBlock?
    private var cameras: AVCaptureDevice.DiscoverySession?
    private var options = MeetingDetectionOptions()
    private var listenerQueue: DispatchQueue?

    func configure(_ options: MeetingDetectionOptions) {
        self.options = options
        cameras = options.cameraEnabled ? AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external], mediaType: .video, position: .unspecified
        ) : nil
    }

    func isActive(inputs: [AudioDeviceID]) -> Bool {
        if cameras?.devices.contains(where: { $0.isInUseByAnotherApplication && !options.excludedDeviceUIDs.contains($0.uniqueID) }) == true { return true }
        let eligible = Set(inputs.filter { device in
            guard let uid = readString(device, selector: kAudioDevicePropertyDeviceUID),
                  !options.excludedDeviceUIDs.contains(uid) else { return false }
            if options.virtualMicrophonesEnabled { return true }
            let transport: UInt32? = readScalar(device, selector: kAudioDevicePropertyTransportType)
            return transport != kAudioDeviceTransportTypeVirtual && transport != kAudioDeviceTransportTypeAggregate
        })
        guard !eligible.isEmpty else { return false }
        guard let processes = readObjects(AudioObjectID(kAudioObjectSystemObject), selector: kAudioHardwarePropertyProcessObjectList) else {
            // Never bypass exclusions when process attribution cannot be read.
            return options.excludedBundleIDs.isEmpty && eligible.contains(where: Self.isRunning)
        }
        for process in processes {
            let running: UInt32? = readScalar(process, selector: kAudioProcessPropertyIsRunningInput)
            guard running == 1 else { continue }
            var value: CFString?
            var address = AudioObjectPropertyAddress(mSelector: kAudioProcessPropertyBundleID, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            var size = UInt32(MemoryLayout<CFString?>.size)
            guard AudioObjectGetPropertyData(process, &address, 0, nil, &size, &value) == noErr, let value else { continue }
            let id = (value as String).lowercased()
            guard !options.excludedBundleIDs.contains(where: { id == $0.lowercased() || id.hasPrefix($0.lowercased() + ".") }),
                  !id.contains("quicklook"), !id.contains("speechrecognition"), !id.contains("dictation") else { continue }
            guard let devices = readObjects(process, selector: kAudioProcessPropertyDevices),
                  !eligible.isDisjoint(with: devices) else { continue }
            return true
        }
        return false
    }

    func availableDevices() -> [MeetingInputDevice] {
        var result = inputDevices().compactMap { device -> MeetingInputDevice? in
            guard let uid = readString(device, selector: kAudioDevicePropertyDeviceUID),
                  let name = readString(device, selector: kAudioObjectPropertyName) else { return nil }
            return MeetingInputDevice(id: uid, name: name)
        }
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external], mediaType: .video, position: .unspecified
        )
        result += discovery.devices.map { MeetingInputDevice(id: $0.uniqueID, name: $0.localizedName) }
        return result
    }

    private func readString(_ object: AudioObjectID, selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var value: CFString?
        var size = UInt32(MemoryLayout<CFString?>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value as String?
    }

    private func readScalar<T>(_ object: AudioObjectID, selector: AudioObjectPropertySelector) -> T? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        let pointer = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<T>.size, alignment: MemoryLayout<T>.alignment)
        defer { pointer.deallocate() }
        var size = UInt32(MemoryLayout<T>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, pointer) == noErr else { return nil }
        return pointer.load(as: T.self)
    }

    private func readObjects(_ object: AudioObjectID, selector: AudioObjectPropertySelector) -> [AudioObjectID]? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(object, &address, 0, nil, &size) == noErr else { return nil }
        var values = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard !values.isEmpty else { return [] }
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &values) == noErr else { return nil }
        return values
    }

    func synchronizeListeners(
        inputs: Set<AudioDeviceID>, queue: DispatchQueue,
        onChange: @escaping @Sendable (Bool) -> Void
    ) -> Bool {
        listenerQueue = queue
        if deviceListListener == nil { deviceListListener = { _, _ in onChange(true) } }
        if runningListener == nil { runningListener = { _, _ in onChange(false) } }
        guard let deviceListListener, let runningListener else { return false }
        if !observesDeviceList {
            var address = Self.deviceListAddress()
            observesDeviceList = AudioObjectAddPropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject), &address, queue, deviceListListener
            ) == noErr
        }
        for device in observedInputs.subtracting(inputs) {
            var address = Self.runningAddress()
            _ = AudioObjectRemovePropertyListenerBlock(device, &address, queue, runningListener)
            observedInputs.remove(device)
        }
        for device in inputs.subtracting(observedInputs) {
            var address = Self.runningAddress()
            if AudioObjectAddPropertyListenerBlock(device, &address, queue, runningListener) == noErr {
                observedInputs.insert(device)
            }
        }
        return observesDeviceList
    }

    func stop() {
        guard let queue = listenerQueue else { return }
        if let runningListener {
            for device in observedInputs {
                var address = Self.runningAddress()
                _ = AudioObjectRemovePropertyListenerBlock(device, &address, queue, runningListener)
            }
        }
        if observesDeviceList, let deviceListListener {
            var address = Self.deviceListAddress()
            _ = AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject), &address, queue, deviceListListener
            )
        }
        observedInputs.removeAll()
        observesDeviceList = false
        deviceListListener = nil
        runningListener = nil
        listenerQueue = nil
    }

    func inputDevices() -> [AudioDeviceID] {
        let system = AudioObjectID(kAudioObjectSystemObject)
        var address = Self.deviceListAddress()
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else {
            return []
        }
        var devices = [AudioDeviceID](
            repeating: 0,
            count: Int(size) / MemoryLayout<AudioDeviceID>.size
        )
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &devices) == noErr else {
            return []
        }
        return devices.filter { Self.hasInputChannels($0) }
    }

    private static func deviceListAddress() -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private static func runningAddress() -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private static func hasInputChannels(_ device: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr,
              size > 0 else { return false }
        let pointer = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: 8)
        defer { pointer.deallocate() }
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, pointer) == noErr else {
            return false
        }
        let buffers = pointer.assumingMemoryBound(to: AudioBufferList.self)
        return UnsafeMutableAudioBufferListPointer(buffers).contains { $0.mNumberChannels > 0 }
    }

    private static func isRunning(_ device: AudioDeviceID) -> Bool {
        var address = runningAddress()
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(device, &address, 0, nil, &size, &running) == noErr
            && running != 0
    }
}
