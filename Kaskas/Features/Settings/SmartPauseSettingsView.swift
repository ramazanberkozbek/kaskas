import AppKit
import SwiftUI

struct SmartPauseSettingsView: View {
    let controller: SessionController

    @State private var microphones: [MicrophoneChoice] = []
    @State private var isChoosingApp = false
    @State private var hasAccessibilityPermission = SmartPauseTriggerMonitor.hasAccessibilityPermission

    private let idleDurations: [TimeInterval] = [1, 2, 3, 5, 10, 15].map { $0 * 60 }
    private let resumeDelays: [TimeInterval] = [0, 60, 120, 300]

    var body: some View {
        Form {
            Section {
                Toggle("smartPause.settings.enabled", isOn: binding(\.smartPauseEnabled))
                Text("smartPause.settings.description")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } header: {
                Text("settings.sidebar.smartPause")
            }

            if controller.configuration.smartPauseEnabled {
                Section {
                    Picker("smartPause.settings.duration", selection: binding(\.smartPauseIdleDuration)) {
                        ForEach(idleDurations, id: \.self) { duration in
                            Text(durationLabel(duration)).tag(duration)
                        }
                    }
                    Text("smartPause.settings.askOnReturn")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("smartPause.settings.section")
                }

                Section {
                    triggerRow(
                        icon: "phone.fill",
                        color: .purple,
                        title: "smartPause.trigger.calls",
                        subtitle: "smartPause.trigger.callsDescription",
                        enabled: binding(\.pauseDuringCalls),
                        notifications: binding(\.notifyDuringCalls)
                    )
                    if controller.configuration.pauseDuringCalls {
                        Picker("smartPause.trigger.microphone", selection: microphoneSelection) {
                            Text("smartPause.trigger.systemDefault").tag("")
                            ForEach(microphones) { microphone in
                                Text(microphone.name).tag(microphone.id)
                            }
                        }
                        .padding(.leading, 38)
                    }

                    triggerRow(
                        icon: "play.rectangle.fill",
                        color: .blue,
                        title: "smartPause.trigger.video",
                        subtitle: "smartPause.trigger.videoDescription",
                        enabled: videoPauseSelection,
                        notifications: binding(\.notifyDuringVideo)
                    )
                    if controller.configuration.pauseDuringVideo && !hasAccessibilityPermission {
                        HStack {
                            Text("smartPause.trigger.accessibilityRequired")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("smartPause.trigger.accessibilityPermission") {
                                SmartPauseTriggerMonitor.requestAccessibilityPermission()
                                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                            }
                        }
                        .padding(.leading, 38)
                    }

                    triggerRow(
                        icon: "square.grid.2x2.fill",
                        color: .pink,
                        title: "smartPause.trigger.focusApps",
                        subtitle: "smartPause.trigger.focusAppsDescription",
                        enabled: binding(\.pauseForFocusApps),
                        notifications: binding(\.notifyForFocusApps)
                    )
                    if controller.configuration.pauseForFocusApps {
                        focusApps
                            .padding(.leading, 38)
                    }
                } header: {
                    Text("smartPause.trigger.section")
                } footer: {
                    Text("smartPause.trigger.note")
                }

                Section {
                    Picker("smartPause.trigger.resumeDelay", selection: binding(\.smartPauseResumeDelay)) {
                        Text("smartPause.trigger.off").tag(TimeInterval(0))
                        ForEach(resumeDelays.dropFirst(), id: \.self) { duration in
                            Text(durationLabel(duration)).tag(duration)
                        }
                    }
                } header: {
                    Text("smartPause.trigger.cooldown")
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            microphones = SmartPauseTriggerMonitor.microphoneChoices()
            hasAccessibilityPermission = SmartPauseTriggerMonitor.hasAccessibilityPermission
        }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            hasAccessibilityPermission = SmartPauseTriggerMonitor.hasAccessibilityPermission
        }
        .sheet(isPresented: $isChoosingApp) {
            FocusAppPicker { app in
                var configuration = controller.configuration
                if !configuration.focusAppBundleIDs.contains(app.id) {
                    configuration.focusAppBundleIDs.append(app.id)
                    controller.updateConfiguration(configuration)
                }
                isChoosingApp = false
            }
        }
    }

    private func triggerRow(
        icon: String,
        color: Color,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        enabled: Binding<Bool>,
        notifications: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Toggle("smartPause.trigger.notify", isOn: notifications)
                .toggleStyle(.checkbox)
                .controlSize(.small)
                .help("smartPause.trigger.notify")
                .disabled(!enabled.wrappedValue)
            Toggle("smartPause.trigger.pause", isOn: enabled)
                .controlSize(.small)
                .help(title)
        }
        .padding(.vertical, 6)
    }

    private var focusApps: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                isChoosingApp = true
            } label: {
                Label("smartPause.trigger.addApp", systemImage: "plus")
            }
            ForEach(controller.configuration.focusAppBundleIDs, id: \.self) { id in
                HStack {
                    Text(NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)
                         .flatMap { Bundle(url: $0)?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String }
                         ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)?.deletingPathExtension().lastPathComponent
                         ?? id)
                    Spacer()
                    Button {
                        var configuration = controller.configuration
                        configuration.focusAppBundleIDs.removeAll { $0 == id }
                        controller.updateConfiguration(configuration)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("smartPause.trigger.removeApp")
                }
            }
        }
    }

    private var microphoneSelection: Binding<String> {
        Binding {
            controller.configuration.microphoneUID ?? ""
        } set: { uid in
            var configuration = controller.configuration
            configuration.microphoneUID = uid.isEmpty ? nil : uid
            controller.updateConfiguration(configuration)
        }
    }

    private var videoPauseSelection: Binding<Bool> {
        Binding {
            controller.configuration.pauseDuringVideo
        } set: { enabled in
            var configuration = controller.configuration
            configuration.pauseDuringVideo = enabled
            controller.updateConfiguration(configuration)
            if enabled && !SmartPauseTriggerMonitor.hasAccessibilityPermission {
                SmartPauseTriggerMonitor.requestAccessibilityPermission()
            }
            hasAccessibilityPermission = SmartPauseTriggerMonitor.hasAccessibilityPermission
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<FocusConfiguration, Value>) -> Binding<Value> {
        Binding {
            controller.configuration[keyPath: keyPath]
        } set: { value in
            var configuration = controller.configuration
            configuration[keyPath: keyPath] = value
            controller.updateConfiguration(configuration)
        }
    }

    private func durationLabel(_ duration: TimeInterval) -> String {
        Measurement(value: duration / 60, unit: UnitDuration.minutes)
            .formatted(.measurement(width: .wide, usage: .asProvided))
    }
}

private struct FocusAppChoice: Identifiable, Sendable {
    let id: String
    let name: String
    let url: URL
}

private struct FocusAppPicker: View {
    let onChoose: (FocusAppChoice) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var apps: [FocusAppChoice] = []
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("smartPause.trigger.focusApps")
                    .font(.title2.bold())
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain)
            }
            .padding()
            TextField("smartPause.trigger.searchApps", text: $search)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredApps) { app in
                    Button {
                        onChoose(app)
                    } label: {
                        HStack(spacing: 12) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                                .resizable()
                                .frame(width: 28, height: 28)
                            Text(app.name)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 450, height: 500)
        .task {
            apps = await Task.detached(priority: .userInitiated) {
                Self.installedApps()
            }.value
            isLoading = false
        }
    }

    private var filteredApps: [FocusAppChoice] {
        search.isEmpty ? apps : apps.filter {
            $0.name.localizedStandardContains(search) || $0.id.localizedStandardContains(search)
        }
    }

    private nonisolated static func installedApps() -> [FocusAppChoice] {
        let folders = [URL(fileURLWithPath: "/Applications"),
                       FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")]
        var found: [String: FocusAppChoice] = [:]
        for folder in folders {
            guard let urls = FileManager.default.enumerator(at: folder,
                                                             includingPropertiesForKeys: nil,
                                                             options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { continue }
            for case let url as URL in urls where url.pathExtension == "app" {
                guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else { continue }
                let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                    ?? url.deletingPathExtension().lastPathComponent
                found[id] = FocusAppChoice(id: id, name: name, url: url)
            }
        }
        return found.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
