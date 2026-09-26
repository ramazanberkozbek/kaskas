import AVFoundation
import CoreAudio
import Foundation

@MainActor
final class MeetingActivityMonitor {
    private var timer: Timer?
    private var lastSample = false
    private var onChange: ((Bool) -> Void)?
    private var observedInputs = Set<AudioDeviceID>()
    private var observesDeviceList = false
    private lazy var audioListener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
        Task { @MainActor [weak self] in
            guard self?.onChange != nil else { return }
            self?.synchronizeAudioListeners()
            self?.poll()
        }
    }
    private let cameras = AVCaptureDevice.DiscoverySession(
        deviceTypes: [.builtInWideAngleCamera, .external],
        mediaType: .video,
        position: .unspecified
    )

    func start(onChange: @escaping (Bool) -> Void) {
        stop()
        self.onChange = onChange
        synchronizeAudioListeners()
        lastSample = sample()
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        onChange = nil
        for device in observedInputs {
            var address = Self.runningAddress()
            _ = AudioObjectRemovePropertyListenerBlock(device, &address, DispatchQueue.main, audioListener)
        }
        observedInputs.removeAll()
        if observesDeviceList {
            var address = Self.deviceListAddress()
            _ = AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main, audioListener
            )
            observesDeviceList = false
        }
    }

    func sample() -> Bool {
        Self.anyInputDeviceRunning() || cameras.devices.contains { $0.isInUseByAnotherApplication }
    }

    private func synchronizeAudioListeners() {
        if !observesDeviceList {
            var address = Self.deviceListAddress()
            observesDeviceList = AudioObjectAddPropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main, audioListener
            ) == noErr
        }
        let inputs = Set(Self.inputDevices())
        for device in observedInputs.subtracting(inputs) {
            var address = Self.runningAddress()
            _ = AudioObjectRemovePropertyListenerBlock(device, &address, DispatchQueue.main, audioListener)
            observedInputs.remove(device)
        }
        for device in inputs.subtracting(observedInputs) {
            var address = Self.runningAddress()
            if AudioObjectAddPropertyListenerBlock(device, &address, DispatchQueue.main, audioListener) == noErr {
                observedInputs.insert(device)
            }
        }
    }

    private func poll() {
        let active = sample()
        guard active != lastSample else { return }
        lastSample = active
        onChange?(active)
    }

    private static func anyInputDeviceRunning() -> Bool {
        inputDevices().contains { isRunning($0) }
    }

    private static func inputDevices() -> [AudioDeviceID] {
        let system = AudioObjectID(kAudioObjectSystemObject)
        var address = deviceListAddress()
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
        return devices.filter { hasInputChannels($0) }
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
