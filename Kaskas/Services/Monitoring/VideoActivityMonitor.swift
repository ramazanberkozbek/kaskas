import AppKit
import Darwin
import IOKit.pwr_mgt

@MainActor
protocol VideoActivityMonitoring {
    func start(excludedBundleIDs: [String], onChange: @escaping (Bool) -> Void)
    func stop()
    func sample() -> Bool
}

/// A positive video signal is required; audio, generic wake locks, editors and
/// unknown players never qualify.
///
/// Contributor guide:
/// - Implemented: Chrome (including Beta/Dev/Canary), Chromium, Edge (including
///   Beta), Brave (including Beta), Arc, Opera, Safari and Safari Technology Preview.
/// - Live checks so far: Chrome and Brave playback reported working by the user;
///   Safari normal YouTube display assertions and their removal were inspected.
///   The other listed browsers/variants still need end-to-end verification.
/// - This is browser/process detection, not a site or genre classifier. Audio-only
///   playback must not pause focus. A visible music video can pause focus. Safari
///   looping Shorts/Reels, silent videos or other media without the required
///   display assertion may not be detected. Do not promise all-site coverage.
/// - Missing browser/player? Please contribute a reproducible issue or adapter:
///   include app/macOS versions, bundle ID, assertion type/name/level, ownership
///   and play/pause/audio-only/background results. Redact unrelated process data.
///   Merely adding a bundle ID or matching "media" is not sufficient evidence.
/// - Add fixtures using actual raw API values to ProtectionTests, verify process
///   ownership (shared WebKit helpers are not Safari-specific), and update this
///   guide and localized support text together.
/// - Preserve exclusions, cached UI reads, worker isolation, stale-result rejection
///   and the existing polling interval. No new permissions should be implicit.
nonisolated enum VideoDetectionPolicy {
    static let browsers: Set<String> = [
        "com.google.chrome", "com.google.chrome.beta", "com.google.chrome.dev", "com.google.chrome.canary",
        "org.chromium.chromium", "com.microsoft.edgemac", "com.microsoft.edgemac.beta",
        "com.brave.browser", "com.brave.browser.beta", "company.thebrowser.browser", "com.operasoftware.opera",
        "com.apple.safari", "com.apple.safaritechnologypreview"
    ]

    static func supports(bundleID: String, excludedBundleIDs: [String]) -> Bool {
        let id = bundleID.lowercased()
        return browsers.contains(id) && !excludedBundleIDs.contains { id == $0.lowercased() }
    }

    static func isVideoAssertion(type: String, name: String, level: Int, bundleID: String = "com.google.chrome") -> Bool {
        // IOPMCopyAssertionsByProcess can return the legacy raw name even
        // though the public constant uses PreventUserIdleDisplaySleep.
        let displaySleepTypes = [kIOPMAssertionTypePreventUserIdleDisplaySleep, "NoDisplaySleepAssertion"]
        guard level == Int(kIOPMAssertionLevelOn), displaySleepTypes.contains(type) else { return false }
        if isSafari(bundleID: bundleID) {
            // WebKit uses the same description for system and display assertions.
            // Only an attributed display assertion identifies visible video.
            return name == "com.apple.WebCore: HTMLMediaElement playback"
        }
        // Current Chromium: Video Wake Lock. Earlier builds: Playing video.
        // Never accept Playing audio, generic display locks, or a name containing "media".
        return ["video wake lock", "playing video"].contains(name.lowercased())
    }

    static func isSafari(bundleID: String) -> Bool {
        ["com.apple.safari", "com.apple.safaritechnologypreview"].contains(bundleID.lowercased())
    }
}

@MainActor
final class VideoActivityMonitor: VideoActivityMonitoring {
    private let worker = VideoActivityWorker()
    private var task: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var callback: ((Bool) -> Void)?
    private var generation = UUID()
    private var revision = 0
    private var excludedBundleIDs: [String] = []
    private var lastSample = false
    private var sampledPID: pid_t?
    private var sampledAt: Date?
    private var sessionActive = true
    private var screensAwake = true
    private var systemAwake = true
    private var available: Bool { sessionActive && screensAwake && systemAwake }

    isolated deinit { stop() }

    func start(excludedBundleIDs: [String], onChange: @escaping (Bool) -> Void) {
        stop()
        self.excludedBundleIDs = excludedBundleIDs
        callback = onChange
        sessionActive = true
        screensAwake = true
        systemAwake = true
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification,
                     NSWorkspace.sessionDidBecomeActiveNotification, NSWorkspace.willSleepNotification,
                     NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    switch name {
                    case NSWorkspace.didWakeNotification: self.systemAwake = true
                    case NSWorkspace.willSleepNotification: self.systemAwake = false
                    case NSWorkspace.screensDidWakeNotification: self.screensAwake = true
                    case NSWorkspace.screensDidSleepNotification: self.screensAwake = false
                    case NSWorkspace.sessionDidBecomeActiveNotification: self.sessionActive = true
                    case NSWorkspace.sessionDidResignActiveNotification: self.sessionActive = false
                    default: break
                    }
                    self.refresh()
                }
            })
        }
        refresh()
        task = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
                guard let self else { return }
                self.refresh()
            }
        }
    }

    func stop() {
        generation = UUID()
        revision += 1
        task?.cancel()
        task = nil
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observers = []
        callback = nil
        lastSample = false
        sampledPID = nil
        sampledAt = nil
    }

    func sample() -> Bool {
        guard available, lastSample, let sampledAt, Date().timeIntervalSince(sampledAt) < 5,
              sampledPID == NSWorkspace.shared.frontmostApplication?.processIdentifier else { return false }
        return true
    }

    private func publish(_ active: Bool, pid: pid_t?) {
        sampledPID = pid
        sampledAt = .now
        guard active != lastSample else { return }
        lastSample = active
        callback?(active)
    }

    private func refresh() {
        // A delayed/unavailable probe must not leave a previously true result
        // latched indefinitely while the focus scheduler is suspended.
        if lastSample, sample() == false { publish(false, pid: nil) }
        revision += 1
        let revision = revision
        guard callback != nil, available, let app = NSWorkspace.shared.frontmostApplication,
              let id = app.bundleIdentifier, let path = app.bundleURL?.path,
              VideoDetectionPolicy.supports(bundleID: id, excludedBundleIDs: excludedBundleIDs) else {
            publish(false, pid: nil)
            return
        }
        let pid = app.processIdentifier
        let generation = generation
        let worker = worker
        Task { [weak self] in
            let active = await worker.isPlaying(pid: pid, appPath: path, bundleID: id)
            guard let self, self.callback != nil, self.generation == generation, self.revision == revision else { return }
            // Do not apply a result sampled for a formerly foreground application.
            guard self.available, NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { return }
            self.publish(active, pid: pid)
        }
    }
}

actor VideoActivityWorker {
    nonisolated let queue = DispatchSerialQueue(label: "com.kaskas.video-power", qos: .utility)
    nonisolated var unownedExecutor: UnownedSerialExecutor { queue.asUnownedSerialExecutor() }

    func isPlaying(pid: pid_t, appPath: String, bundleID: String) -> Bool {
        var dictionary: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&dictionary) == kIOReturnSuccess,
              let assertions = dictionary?.takeRetainedValue() as? [NSNumber: [[String: Any]]] else { return false }
        for (owner, entries) in assertions {
            guard entries.contains(where: { entry in
                VideoDetectionPolicy.isVideoAssertion(
                    type: entry[kIOPMAssertionTypeKey] as? String ?? "",
                    name: entry[kIOPMAssertionNameKey] as? String ?? "",
                    level: (entry[kIOPMAssertionLevelKey] as? NSNumber)?.intValue ?? 0,
                    bundleID: bundleID
                )
            }) else { continue }
            if owner.int32Value == pid { return true }
            // Safari's UI process owns the forwarded WebCore assertion. Shared
            // WebKit helpers cannot be attributed by path to Safari alone.
            if VideoDetectionPolicy.isSafari(bundleID: bundleID) { continue }
            // Chromium can own the assertion in a helper process. Attribute that
            // helper to the foreground .app by executable path, never by display name.
            var bytes = [CChar](repeating: 0, count: 4096)
            let length = proc_pidpath(owner.int32Value, &bytes, UInt32(bytes.count))
            if length > 0, String(cString: bytes).hasPrefix(appPath + "/") { return true }
        }
        return false
    }
}
