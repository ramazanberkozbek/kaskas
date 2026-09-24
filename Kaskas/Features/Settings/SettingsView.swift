import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    let controller: SessionController

    @State private var selection: SettingsPane = .focus
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: $selection) { pane in
                Label(pane.title, systemImage: pane.systemImage)
                    .tag(pane)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .navigationSplitViewColumnWidth(
                min: 180, ideal: 200, max: 260
            )
            .safeAreaInset(edge: .top) {
                Color.clear.frame(height: 6)
            }
        } detail: {
            detailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .background(SettingsWindowChrome(colorScheme: colorScheme))
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selection {
        case .focus:
            FocusSettingsView(controller: controller)
        case .wellness:
            WellnessSettingsView(controller: controller)
        case .smartPause:
            SettingsPlaceholderView(pane: .smartPause)
        case .alerts:
            SettingsPlaceholderView(pane: .alerts)
        case .statistics:
            SettingsPlaceholderView(pane: .statistics)
        case .general:
            GeneralSettingsView()
        }
    }
}

private enum SettingsPane: String, CaseIterable, Identifiable {
    case focus
    case wellness
    case smartPause
    case alerts
    case statistics
    case general

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .focus: "settings.sidebar.focus"
        case .wellness: "settings.sidebar.wellness"
        case .smartPause: "settings.sidebar.smartPause"
        case .alerts: "settings.sidebar.alerts"
        case .statistics: "settings.sidebar.statistics"
        case .general: "settings.sidebar.general"
        }
    }

    var systemImage: String {
        switch self {
        case .focus: "leaf"
        case .wellness: "waveform.path.ecg"
        case .smartPause: "pause.circle"
        case .alerts: "bell.badge"
        case .statistics: "chart.bar.xaxis"
        case .general: "gearshape"
        }
    }
}

private struct FocusSettingsView: View {
    let controller: SessionController

    private let focusDurations: [TimeInterval] = [10, 15, 20, 30, 45, 60, 90].map { $0 * 60 }
    private let breakDurations: [TimeInterval] = [1, 3, 5, 10, 15].map { $0 * 60 }
    private let snoozeDurations: [TimeInterval] = [3, 5, 10, 15].map { $0 * 60 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // Live miniature preview of the break screen
                BreakMiniPreviewCard(
                    configuration: controller.configuration,
                    onFullscreen: {
                        controller.previewBreak()
                    }
                )

                // Background appearance customization
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("settings.breakAppearance.sectionTitle")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)

                        Text("settings.breakAppearance.sectionSubtitle")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 0) {
                        // Style: Frost vs Clear
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("settings.breakAppearance.style")
                                    .font(.body.weight(.medium))

                                Text("settings.breakAppearance.styleDescription")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Picker("", selection: breakBackgroundStyle) {
                                Text("settings.breakAppearance.frost").tag(BreakBackgroundStyle.frost)
                                Text("settings.breakAppearance.clear").tag(BreakBackgroundStyle.clear)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 170)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)

                        Divider()
                            .padding(.leading, 16)

                        // Overlay intensity slider
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("settings.breakAppearance.overlay")
                                    .font(.body.weight(.medium))

                                Text("settings.breakAppearance.overlayDescription")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            HStack(spacing: 12) {
                                Slider(value: breakOverlayDim, in: 0.10...0.85, step: 0.05)
                                    .frame(width: 150)

                                Text("\(Int(controller.configuration.breakOverlayDim * 100))%")
                                    .font(.callout.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 36, alignment: .trailing)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)

                        Divider()
                            .padding(.leading, 16)

                        // Preset Wallpapers Horizontal Strip
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                // None / Calm gradient
                                WallpaperChoiceThumbnail(
                                    background: .calmGradient,
                                    title: "settings.breakAppearance.none",
                                    selectedBackground: controller.configuration.breakBackground,
                                    onSelect: {
                                        updateBackground(.calmGradient)
                                    }
                                ) {
                                    ZStack {
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.08, green: 0.10, blue: 0.14),
                                                Color(red: 0.04, green: 0.05, blue: 0.08)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )

                                        Image(systemName: "circle.slash")
                                            .font(.system(size: 22, weight: .light))
                                            .foregroundStyle(.white.opacity(0.4))
                                    }
                                }

                                // Mountain Lake (Lake Tahoe)
                                WallpaperChoiceThumbnail(
                                    background: .mountainLake,
                                    title: "settings.breakAppearance.mountainLake",
                                    selectedBackground: controller.configuration.breakBackground,
                                    onSelect: {
                                        updateBackground(.mountainLake)
                                    }
                                ) {
                                    Image("BreakMountainLake")
                                        .resizable()
                                        .scaledToFill()
                                }

                                // Snow Peaks
                                WallpaperChoiceThumbnail(
                                    background: .snowPeaks,
                                    title: "settings.breakAppearance.snowPeaks",
                                    selectedBackground: controller.configuration.breakBackground,
                                    onSelect: {
                                        updateBackground(.snowPeaks)
                                    }
                                ) {
                                    Image("BreakSnowPeaks")
                                        .resizable()
                                        .scaledToFill()
                                }

                                // Aurora
                                WallpaperChoiceThumbnail(
                                    background: .aurora,
                                    title: "settings.breakAppearance.aurora",
                                    selectedBackground: controller.configuration.breakBackground,
                                    onSelect: {
                                        updateBackground(.aurora)
                                    }
                                ) {
                                    Image("BreakAurora")
                                        .resizable()
                                        .scaledToFill()
                                }

                                // Desert Dunes
                                WallpaperChoiceThumbnail(
                                    background: .desertDunes,
                                    title: "settings.breakAppearance.desertDunes",
                                    selectedBackground: controller.configuration.breakBackground,
                                    onSelect: {
                                        updateBackground(.desertDunes)
                                    }
                                ) {
                                    Image("BreakDesertDunes")
                                        .resizable()
                                        .scaledToFill()
                                }

                                // Cosmic Space
                                WallpaperChoiceThumbnail(
                                    background: .cosmic,
                                    title: "settings.breakAppearance.cosmic",
                                    selectedBackground: controller.configuration.breakBackground,
                                    onSelect: {
                                        updateBackground(.cosmic)
                                    }
                                ) {
                                    Image("BreakCosmic")
                                        .resizable()
                                        .scaledToFill()
                                }

                                // Custom Wallpaper upload button / choice
                                CustomWallpaperChoiceThumbnail(
                                    customPath: controller.configuration.customWallpaperPath,
                                    isSelected: controller.configuration.breakBackground == .custom,
                                    onSelect: {
                                        if controller.configuration.customWallpaperPath != nil {
                                            updateBackground(.custom)
                                        } else {
                                            chooseCustomWallpaper()
                                        }
                                    },
                                    onPickNew: {
                                        chooseCustomWallpaper()
                                    }
                                )
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                    }
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    }
                }

                // Schedule Durations Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("settings.schedule.title")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)

                    VStack(spacing: 0) {
                        SettingsDurationRow(
                            title: "settings.focusDuration",
                            subtitle: "settings.focusDuration.description",
                            selection: binding(for: \FocusConfiguration.focusDuration),
                            options: focusDurations
                        )

                        Divider()
                            .padding(.leading, 16)

                        SettingsDurationRow(
                            title: "settings.breakDuration",
                            subtitle: "settings.breakDuration.description",
                            selection: binding(for: \FocusConfiguration.breakDuration),
                            options: breakDurations
                        )

                        Divider()
                            .padding(.leading, 16)

                        SettingsDurationRow(
                            title: "settings.snoozeDuration",
                            subtitle: "settings.snoozeDuration.description",
                            selection: binding(for: \FocusConfiguration.snoozeDuration),
                            options: snoozeDurations
                        )
                    }
                    .padding(.horizontal, 16)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    }

                    Text("settings.nextCycle.note")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
            }
            .padding(20)
        }
    }

    private func binding(
        for keyPath: WritableKeyPath<FocusConfiguration, TimeInterval>
    ) -> Binding<TimeInterval> {
        Binding {
            controller.configuration[keyPath: keyPath]
        } set: { newValue in
            var configuration = controller.configuration
            configuration[keyPath: keyPath] = newValue
            controller.updateConfiguration(configuration)
        }
    }

    private var breakBackgroundStyle: Binding<BreakBackgroundStyle> {
        Binding {
            controller.configuration.breakBackgroundStyle
        } set: { newValue in
            var configuration = controller.configuration
            configuration.breakBackgroundStyle = newValue
            controller.updateConfiguration(configuration)
        }
    }

    private var breakOverlayDim: Binding<Double> {
        Binding {
            controller.configuration.breakOverlayDim
        } set: { newValue in
            var configuration = controller.configuration
            configuration.breakOverlayDim = newValue
            controller.updateConfiguration(configuration)
        }
    }

    private func updateBackground(_ background: BreakBackground) {
        var configuration = controller.configuration
        configuration.breakBackground = background
        controller.updateConfiguration(configuration)
    }

    private func chooseCustomWallpaper() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        panel.prompt = "Seç"
        panel.message = "Mola ekranı için bir arka plan görseli seçin"

        if panel.runModal() == .OK, let url = panel.url {
            saveCustomWallpaper(from: url)
        }
    }

    private func saveCustomWallpaper(from sourceURL: URL) {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return }

        let kaskasFolder = appSupport.appendingPathComponent("com.ramazanozbek.kaskas", isDirectory: true)
        try? FileManager.default.createDirectory(at: kaskasFolder, withIntermediateDirectories: true)

        let targetURL = kaskasFolder.appendingPathComponent("custom_wallpaper.\(sourceURL.pathExtension)")
        try? FileManager.default.removeItem(at: targetURL)
        try? FileManager.default.copyItem(at: sourceURL, to: targetURL)

        var config = controller.configuration
        config.customWallpaperPath = targetURL.path
        config.breakBackground = .custom
        controller.updateConfiguration(config)
    }
}

private struct BreakMiniPreviewCard: View {
    let configuration: FocusConfiguration
    let onFullscreen: () -> Void

    var body: some View {
        ZStack {
            // Live rendering of the background
            BreakBackgroundView(
                background: configuration.breakBackground,
                style: configuration.breakBackgroundStyle,
                overlayDim: configuration.breakOverlayDim,
                customWallpaperPath: configuration.customWallpaperPath
            )

            // Scaled miniature break content
            VStack(spacing: 5) {
                // Top localized date
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.top, 14)

                Spacer()

                VStack(spacing: 4) {
                    Text("break.title")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 4, y: 1)

                    Text("break.message")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .shadow(color: .black.opacity(0.35), radius: 3, y: 1)

                    Capsule()
                        .fill(.white.opacity(0.35))
                        .frame(width: 36, height: 1.5)
                        .padding(.top, 2)

                    Text("00:20")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 5, y: 2)

                    HStack(spacing: 8) {
                        miniPill(title: "break.snooze", icon: "clock.arrow.circlepath")
                        miniPill(title: "break.skip", icon: "forward.end.fill")
                        miniPill(title: "break.lockScreen", icon: "lock.fill")
                    }
                    .padding(.top, 2)

                    HStack(spacing: 3) {
                        Text("break.press")
                        Text("esc")
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.white.opacity(0.25), in: RoundedRectangle(cornerRadius: 2.5))
                        Text("break.toSkip")
                    }
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                    .tracking(0.8)
                }

                Spacer()
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)

            // Top overlay bar with Live Preview badge and Fullscreen button
            VStack {
                HStack {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(.green)
                            .frame(width: 5, height: 5)

                        Text("settings.breakAppearance.livePreview")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay {
                        Capsule().stroke(.white.opacity(0.2), lineWidth: 0.5)
                    }

                    Spacer()

                    Button(action: onFullscreen) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay {
                                Circle().stroke(.white.opacity(0.2), lineWidth: 0.5)
                            }
                    }
                    .buttonStyle(.plain)
                    .help("settings.breakAppearance.fullscreenPreview")
                }
                .padding(12)

                Spacer()
            }
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        }
    }

    private func miniPill(title: LocalizedStringKey, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .bold))
            Text(title)
                .font(.system(size: 8.5, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule().stroke(.white.opacity(0.22), lineWidth: 0.5)
        }
    }
}

private struct WallpaperChoiceThumbnail<Content: View>: View {
    let background: BreakBackground
    let title: LocalizedStringKey
    let selectedBackground: BreakBackground
    let onSelect: () -> Void
    @ViewBuilder let content: Content

    private var isSelected: Bool {
        selectedBackground == background
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                content
                    .frame(width: 96, height: 60)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                isSelected ? Color.accentColor : .white.opacity(0.15),
                                lineWidth: isSelected ? 2.5 : 1
                            )
                    }
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color.accentColor)
                                .padding(5)
                        }
                    }

                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct CustomWallpaperChoiceThumbnail: View {
    let customPath: String?
    let isSelected: Bool
    let onSelect: () -> Void
    let onPickNew: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                ZStack {
                    if let path = customPath, let nsImage = NSImage(contentsOfFile: path) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.black.opacity(0.3)

                        VStack(spacing: 4) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 18))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(width: 96, height: 60)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay {
                    if customPath == nil {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                style: StrokeStyle(lineWidth: 1.5, dash: [4])
                            )
                            .foregroundStyle(isSelected ? Color.accentColor : .white.opacity(0.25))
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                isSelected ? Color.accentColor : .white.opacity(0.15),
                                lineWidth: isSelected ? 2.5 : 1
                            )
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.accentColor)
                            .padding(5)
                    }
                }
                .contextMenu {
                    Button("settings.breakAppearance.upload", action: onPickNew)
                }

                Text(customPath == nil ? "settings.breakAppearance.upload" : "settings.breakAppearance.custom")
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct WellnessSettingsView: View {
    let controller: SessionController

    private let reminderIntervals: [TimeInterval] = [5, 10, 15, 20, 25, 30].map { $0 * 60 }

    var body: some View {
        Form {
            Section("settings.wellness.section") {
                SettingsDurationRow(
                    title: "settings.reminderInterval",
                    subtitle: "settings.reminderInterval.description",
                    selection: reminderInterval,
                    options: reminderIntervals
                )
            }
        }
        .formStyle(.grouped)
    }

    private var reminderInterval: Binding<TimeInterval> {
        Binding {
            controller.configuration.microReminderInterval
        } set: { newValue in
            var configuration = controller.configuration
            configuration.microReminderInterval = newValue
            controller.updateConfiguration(configuration)
        }
    }
}

private struct SettingsDurationRow: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    @Binding var selection: TimeInterval
    let options: [TimeInterval]

    var body: some View {
        LabeledContent {
            Picker("", selection: $selection) {
                ForEach(options, id: \.self) { duration in
                    Text(Self.formattedDuration(duration))
                        .tag(duration)
                }
            }
            .labelsHidden()
            .frame(width: 170)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    private static func formattedDuration(_ seconds: TimeInterval) -> String {
        Measurement(
            value: seconds / 60,
            unit: UnitDuration.minutes
        ).formatted(
            .measurement(width: .wide, usage: .asProvided)
        )
    }
}

private struct SettingsPlaceholderView: View {
    let pane: SettingsPane

    var body: some View {
        ContentUnavailableView {
            Label(pane.title, systemImage: pane.systemImage)
        } description: {
            Text("settings.comingSoon")
        }
    }
}

private struct GeneralSettingsView: View {
    var body: some View {
        Form {
            Section("settings.privacy.title") {
                LabeledContent {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } label: {
                    Label("settings.privacy.local", systemImage: "lock.shield")
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Window Chrome

/// Configures the Settings window so the title bar is transparent and the
/// traffic lights sit inline with the sidebar, matching the SpacedRepetition
/// project's MacWindowChromeConfigurator approach.
private struct SettingsWindowChrome: NSViewRepresentable {
    var colorScheme: ColorScheme

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(window: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if !context.coordinator.isConfigured, let window = nsView.window {
            configure(window: window)
            context.coordinator.isConfigured = true
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var isConfigured = false
    }

    private func configure(window: NSWindow?) {
        guard let window else { return }
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = colorScheme == .dark
            ? NSColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1.0)
            : .windowBackgroundColor
    }
}
