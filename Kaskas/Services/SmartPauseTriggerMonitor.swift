import AppKit
import ApplicationServices
import CoreAudio

struct MicrophoneChoice: Identifiable, Equatable {
    let id: String
    let name: String
}

enum SmartPauseTrigger: String, CaseIterable, Hashable, Sendable {
    case calls
    case video
    case focusApp
}

@MainActor
final class SmartPauseTriggerMonitor {
    private var timer: Timer?
    private var videoSampleInFlight = false
    private var videoIsPlaying = false
    private var generation = 0
    private var onSample: (@MainActor @Sendable (Date, Set<SmartPauseTrigger>) -> Void)?

    func start(onSample: @escaping @MainActor @Sendable (Date, Set<SmartPauseTrigger>) -> Void) {
        stop()
        self.onSample = onSample
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.sampleVideo()
                onSample(Date(), self.activeTriggers())
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        sampleVideo()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        generation += 1
        videoSampleInFlight = false
        videoIsPlaying = false
        onSample = nil
    }

    var configuration = FocusConfiguration() {
        didSet {
            if !configuration.pauseDuringVideo { videoIsPlaying = false }
            sampleVideo()
        }
    }

    func activeTriggers() -> Set<SmartPauseTrigger> {
        guard configuration.smartPauseEnabled else { return [] }
        var result = Set<SmartPauseTrigger>()
        if configuration.pauseDuringCalls && Self.isMicrophoneRunning(uid: configuration.microphoneUID) {
            result.insert(.calls)
        }
        if configuration.pauseDuringVideo && videoIsPlaying {
            result.insert(.video)
        }
        if configuration.pauseForFocusApps,
           let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           configuration.focusAppBundleIDs.contains(bundleID) {
            result.insert(.focusApp)
        }
        return result
    }

    static var hasAccessibilityPermission: Bool { AXIsProcessTrusted() }

    static func requestAccessibilityPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func sampleVideo() {
        guard timer != nil, !videoSampleInFlight else { return }
        guard configuration.smartPauseEnabled, configuration.pauseDuringVideo,
              Self.hasAccessibilityPermission,
              let application = NSWorkspace.shared.frontmostApplication,
              application.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            if videoIsPlaying {
                videoIsPlaying = false
                onSample?(Date(), activeTriggers())
            }
            return
        }
        videoSampleInFlight = true
        let pid = application.processIdentifier
        let sampleGeneration = generation
        Task.detached { [weak self] in
            let isPlaying = Self.isVideoPlaying(in: pid)
            await MainActor.run {
                guard let self, self.generation == sampleGeneration else { return }
                self.videoSampleInFlight = false
                self.videoIsPlaying = isPlaying
                    && self.configuration.smartPauseEnabled
                    && self.configuration.pauseDuringVideo
                    && NSWorkspace.shared.frontmostApplication?.processIdentifier == pid
                self.onSample?(Date(), self.activeTriggers())
            }
        }
    }

    nonisolated private static func isVideoPlaying(in pid: pid_t) -> Bool {
        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appElement, 0.1)
        guard let windowValue = attribute(kAXFocusedWindowAttribute, from: appElement),
              CFGetTypeID(windowValue) == AXUIElementGetTypeID() else {
            return false
        }
        let window = windowValue as! AXUIElement
        var remainingNodes = 250
        return videoState(in: window, depth: 0, remainingNodes: &remainingNodes).isPlaying
    }

    nonisolated private struct VideoState {
        var hasVideo = false
        var hasPauseControl = false
        var isPlaying: Bool { hasVideo && hasPauseControl }
    }

    nonisolated private static func videoState(
        in element: AXUIElement,
        depth: Int,
        remainingNodes: inout Int
    ) -> VideoState {
        guard depth < 14, remainingNodes > 0 else { return VideoState() }
        remainingNodes -= 1
        let role = (attribute(kAXRoleAttribute, from: element) as? String ?? "").lowercased()
        let description = (attribute(kAXRoleDescriptionAttribute, from: element) as? String ?? "").lowercased()
        let title = (attribute(kAXTitleAttribute, from: element) as? String ?? "").lowercased()
        var state = VideoState()
        state.hasVideo = role.contains("video") || description.contains("video") || description.contains("video oynatıcı")
        if role == "axbutton" {
            state.hasPauseControl = ["pause", "duraklat"].contains { title == $0 || title.hasPrefix("\($0) ") }
        }
        if let children = attribute(kAXChildrenAttribute, from: element) as? [AXUIElement] {
            for child in children {
                let childState = videoState(in: child, depth: depth + 1, remainingNodes: &remainingNodes)
                state.hasVideo = state.hasVideo || childState.hasVideo
                state.hasPauseControl = state.hasPauseControl || childState.hasPauseControl
                if state.isPlaying { break }
            }
        }
        return state
    }

    nonisolated private static func attribute(_ name: String, from element: AXUIElement) -> AnyObject? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    static func microphoneChoices() -> [MicrophoneChoice] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject),
                                             &address, 0, nil, &size) == noErr else { return [] }
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address,
                                         0, nil, &size, &devices) == noErr else { return [] }
        return devices.compactMap { device in
            guard hasInputChannels(device),
                  let uid = stringProperty(kAudioDevicePropertyDeviceUID, device: device),
                  let name = stringProperty(kAudioObjectPropertyName, device: device) else { return nil }
            return MicrophoneChoice(id: uid, name: name)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func isMicrophoneRunning(uid: String?) -> Bool {
        let device: AudioDeviceID
        if let uid {
            guard let chosen = deviceID(for: uid) else { return false }
            device = chosen
        } else {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultInputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var value = AudioDeviceID(0)
            var size = UInt32(MemoryLayout<AudioDeviceID>.size)
            guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address,
                                             0, nil, &size, &value) == noErr else { return false }
            device = value
        }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(device, &address, 0, nil, &size, &running) == noErr
            && running != 0
    }

    private static func hasInputChannels(_ device: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
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
        let list = pointer.assumingMemoryBound(to: AudioBufferList.self)
        return UnsafeMutableAudioBufferListPointer(list).contains { $0.mNumberChannels > 0 }
    }

    private static func stringProperty(_ selector: AudioObjectPropertySelector,
                                       device: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<CFString>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else {
            return nil
        }
        return value?.takeRetainedValue() as String?
    }

    private static func deviceID(for uid: String) -> AudioDeviceID? {
        microphoneChoices().first(where: { $0.id == uid }).flatMap { choice in
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDevices,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var size: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject),
                                                 &address, 0, nil, &size) == noErr else { return nil }
            var devices = [AudioDeviceID](repeating: 0,
                                          count: Int(size) / MemoryLayout<AudioDeviceID>.size)
            guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address,
                                             0, nil, &size, &devices) == noErr else { return nil }
            return devices.first { stringProperty(kAudioDevicePropertyDeviceUID, device: $0) == choice.id }
        }
    }
}
