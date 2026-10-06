import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct FocusSettingsView: View {
    let controller: SessionController
    @State private var wallpaperImportTask: Task<Void, Never>?
    @Environment(\.colorScheme) private var colorScheme
    private let focusDurations: [TimeInterval] = [15, 20, 25, 30, 45, 60].map { $0 * 60 }
    private let breakDurations: [TimeInterval] = [1, 3, 5, 10].map { $0 * 60 }
    private let longBreakDurations: [TimeInterval] = [5, 10, 15, 30].map { $0 * 60 }
    private let snoozeDurations: [TimeInterval] = [3, 5, 10, 15].map { $0 * 60 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsPageLayout.sectionSpacing) {
                SettingsPaneHeader(title: "settings.sidebar.focus")

                // 1. Break Schedule
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeading(
                        "settings.schedule.title",
                        subtitle: "settings.nextCycle.note"
                    )

                    VStack(spacing: 0) {
                        durationRow(
                            "settings.focusDuration",
                            subtitle: "settings.focusDuration.description",
                            selection: binding(for: \.focusDuration),
                            options: focusDurations
                        )

                        rowDivider

                        durationRow(
                            "settings.breakDuration",
                            subtitle: "settings.breakDuration.description",
                            selection: binding(for: \.breakDuration),
                            options: breakDurations
                        )

                        rowDivider

                        durationRow(
                            "settings.snoozeDuration",
                            subtitle: "settings.snoozeDuration.description",
                            selection: binding(for: \.snoozeDuration),
                            options: snoozeDurations
                        )

                        rowDivider

                        settingRow(
                            "settings.longBreak.enabled",
                            subtitle: "settings.longBreak.description"
                        ) {
                            Toggle("settings.longBreak.enabled", isOn: binding(for: \.longBreakEnabled))
                                .labelsHidden()
                                .toggleStyle(.switch)
                        }

                        if controller.configuration.longBreakEnabled {
                            rowDivider

                            settingRow(
                                "settings.longBreak.frequency",
                                subtitle: "settings.longBreak.frequency.description"
                            ) {
                                SettingsMenuPicker(
                                    title: "settings.longBreak.frequency",
                                    selection: binding(for: \.longBreakFrequency),
                                    selectedLabel: controller.configuration.longBreakFrequency == 1
                                        ? Text("Her molada")
                                        : Text("\(controller.configuration.longBreakFrequency) molada bir")
                                ) {
                                    ForEach(1...10, id: \.self) { frequency in
                                        if frequency == 1 {
                                            Text("Her molada").tag(frequency)
                                        } else {
                                            Text("\(frequency) molada bir").tag(frequency)
                                        }
                                    }
                                }
                            }

                            rowDivider

                            durationRow(
                                "settings.longBreak.duration",
                                subtitle: "settings.longBreak.duration.description",
                                selection: binding(for: \.longBreakDuration),
                                options: longBreakDurations
                            )
                        }

                        rowDivider

                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                            Text("settings.nextCycle.note")
                                .font(.system(size: 11.5))
                            Spacer()
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, SettingsPageLayout.cardInset)
                        .padding(.vertical, 10)
                    }
                    .background(cardBackground, in: RoundedRectangle(cornerRadius: 16))
                }

                // 2. Live Break Preview (Hero Card)
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeading("settings.alerts.preview")

                    BreakMiniPreviewCard(
                        configuration: controller.configuration,
                        onFullscreen: { controller.previewBreak() }
                    )
                }

                // 3. Background / Wallpaper Section
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeading(
                        "settings.breakAppearance.sectionTitle",
                        subtitle: "settings.breakAppearance.sectionSubtitle"
                    )

                    VStack(alignment: .leading, spacing: 0) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                WallpaperChoiceThumbnail(
                                    background: .ocean,
                                    title: "settings.breakAppearance.ocean",
                                    selectedBackground: controller.configuration.breakBackground,
                                    onSelect: { updateBackground(.ocean) }
                                ) {
                                    Image("BreakOcean")
                                        .resizable()
                                        .scaledToFill()
                                }

                                WallpaperChoiceThumbnail(
                                    background: .mountainLake,
                                    title: "settings.breakAppearance.mountainLake",
                                    selectedBackground: controller.configuration.breakBackground,
                                    onSelect: { updateBackground(.mountainLake) }
                                ) {
                                    Image("BreakMountainLake")
                                        .resizable()
                                        .scaledToFill()
                                }

                                WallpaperChoiceThumbnail(
                                    background: .snowPeaks,
                                    title: "settings.breakAppearance.snowPeaks",
                                    selectedBackground: controller.configuration.breakBackground,
                                    onSelect: { updateBackground(.snowPeaks) }
                                ) {
                                    Image("BreakSnowPeaks")
                                        .resizable()
                                        .scaledToFill()
                                }

                                WallpaperChoiceThumbnail(
                                    background: .aurora,
                                    title: "settings.breakAppearance.aurora",
                                    selectedBackground: controller.configuration.breakBackground,
                                    onSelect: { updateBackground(.aurora) }
                                ) {
                                    Image("BreakAurora")
                                        .resizable()
                                        .scaledToFill()
                                }

                                WallpaperChoiceThumbnail(
                                    background: .desertDunes,
                                    title: "settings.breakAppearance.desertDunes",
                                    selectedBackground: controller.configuration.breakBackground,
                                    onSelect: { updateBackground(.desertDunes) }
                                ) {
                                    Image("BreakDesertDunes")
                                        .resizable()
                                        .scaledToFill()
                                }

                                WallpaperChoiceThumbnail(
                                    background: .cosmic,
                                    title: "settings.breakAppearance.cosmic",
                                    selectedBackground: controller.configuration.breakBackground,
                                    onSelect: { updateBackground(.cosmic) }
                                ) {
                                    Image("BreakCosmic")
                                        .resizable()
                                        .scaledToFill()
                                }

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
                                    onPickNew: { chooseCustomWallpaper() }
                                )
                            }
                            .padding(SettingsPageLayout.cardInset)
                        }
                    }
                    .background(cardBackground, in: RoundedRectangle(cornerRadius: 16))
                }

                // 4. Break Layout Section
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeading(
                        "settings.breakLayout.title",
                        subtitle: "settings.breakLayout.subtitle"
                    )

                    VStack(spacing: 0) {
                        settingRow("settings.breakLayout.choice") {
                            BreakLayoutSegmentedPicker(selection: breakLayoutBinding)
                        }
                    }
                    .background(cardBackground, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .settingsPageContent()
        }
        .scrollIndicators(.hidden)
        .background(colorScheme == .dark
            ? Color(red: 0.075, green: 0.075, blue: 0.075)
            : Color(nsColor: .windowBackgroundColor))
        .onDisappear {
            wallpaperImportTask?.cancel()
            wallpaperImportTask = nil
        }
    }

    // MARK: - Helper Row and Header Views

    private func sectionHeading(_ title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var cardBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.115, green: 0.115, blue: 0.115)
            : Color(nsColor: .controlBackgroundColor)
    }

    private var rowDivider: some View {
        Divider().padding(.horizontal, SettingsPageLayout.cardInset)
    }

    private func settingRow<Control: View>(
        _ title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(.primary)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 16)

            control()
        }
        .frame(minHeight: 56)
        .padding(.horizontal, SettingsPageLayout.cardInset)
        .padding(.vertical, 6)
    }

    private func durationRow(
        _ title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        selection: Binding<TimeInterval>,
        options: [TimeInterval]
    ) -> some View {
        settingRow(title, subtitle: subtitle) {
            SettingsDurationPicker(
                title: title,
                selection: selection,
                options: options
            )
        }
    }

    // MARK: - Background & Wallpaper Operations

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
        panel.prompt = String(localized: "Seç")
        panel.message = String(localized: "settings.breakAppearance.chooseImageMessage", defaultValue: "Mola ekranı için bir arka plan görseli seçin")

        if panel.runModal() == .OK, let url = panel.url {
            wallpaperImportTask?.cancel()
            wallpaperImportTask = Task {
                do {
                    try await controller.setCustomWallpaper(from: url)
                } catch is CancellationError {
                    // A newer import superseded this selection.
                } catch {
                    guard !Task.isCancelled else { return }
                    let alert = NSAlert()
                    alert.alertStyle = .warning
                    alert.messageText = localizedString("settings.wallpaper.copyFailed", locale: controller.locale)
                    alert.informativeText = localizedString("settings.wallpaper.copyFailed.description", locale: controller.locale)
                    alert.runModal()
                }
            }
        }
    }

    // MARK: - Formatters & Bindings


    private var breakLayoutBinding: Binding<BreakLayout> {
        Binding {
            controller.configuration.breakLayout
        } set: { newLayout in
            withAnimation(.easeInOut(duration: 0.2)) {
                var configuration = controller.configuration
                configuration.breakLayout = newLayout
                controller.updateConfiguration(configuration)
            }
        }
    }

    private func binding<Value>(
        for keyPath: WritableKeyPath<FocusConfiguration, Value>
    ) -> Binding<Value> {
        Binding {
            controller.configuration[keyPath: keyPath]
        } set: { newValue in
            var configuration = controller.configuration
            configuration[keyPath: keyPath] = newValue
            controller.updateConfiguration(configuration)
        }
    }
}

// MARK: - Break Layout Segmented Picker

struct BreakLayoutSegmentedPicker: View {
    @Binding var selection: BreakLayout
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            segment(for: .horizon, title: "settings.breakLayout.horizon", icon: "sun.horizon")
            segment(for: .gentleBar, title: "settings.breakLayout.gentleBar", icon: "dock.rectangle")
        }
        .frame(width: 216, height: 44)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                .frame(height: 30)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08), lineWidth: 0.5)
                )
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("settings.breakLayout.choice"))
    }

    private func segment(for layout: BreakLayout, title: LocalizedStringKey, icon: String) -> some View {
        let isSelected = selection == layout
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selection = layout
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11.5, weight: .medium))
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            }
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 25)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.18) : Color.white)
                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.12), radius: 1.5, y: 0.5)
                }
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Live Break Preview Card

struct BreakMiniPreviewCard: View {
    let configuration: FocusConfiguration
    let onFullscreen: () -> Void

    var body: some View {
        ZStack {
            // Live background render
            BreakBackgroundView(
                background: configuration.breakBackground,
                customWallpaperPath: configuration.customWallpaperPath
            )

            // Preview content
            VStack(spacing: 0) {
                // Top Bar: "Live preview", Date, Fullscreen Button
                ZStack {
                    Text(Date.now, format: .dateTime.weekday(.wide).day().month(.abbreviated).locale(configuration.appLanguage.locale))
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)

                    HStack(alignment: .center) {
                        Text("settings.breakAppearance.livePreview")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.92))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.48), in: RoundedRectangle(cornerRadius: 6))
                            .overlay {
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                            }

                        Spacer()

                        Button(action: onFullscreen) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(Color.black.opacity(0.48), in: RoundedRectangle(cornerRadius: 6))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, SettingsPageLayout.cardInset)
                .padding(.top, 14)

                if configuration.breakLayout == .gentleBar {
                    Spacer()

                    // Gentle Bar Layout
                    VStack(spacing: 10) {
                        HStack(alignment: .bottom, spacing: 16) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("break.title")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                    .shadow(color: .black.opacity(0.4), radius: 4, y: 1)

                                Text("break.message")
                                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .lineLimit(2)
                                    .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)

                            VStack(alignment: .trailing, spacing: 6) {
                                Text("00:20")
                                    .font(.system(size: 30, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(.white)
                                    .shadow(color: .black.opacity(0.4), radius: 5, y: 2)

                                HStack(spacing: 5) {
                                    miniPill(title: "break.snooze", icon: "clock")
                                    miniPill(title: "break.skip", icon: "forward.fill")
                                    miniPill(title: "break.lockScreen", icon: "lock.fill")
                                }
                            }
                        }
                        .padding(.horizontal, 20)

                        // Press esc to skip
                        HStack(spacing: 3) {
                            Text("break.press")
                            Text("esc")
                                .font(.system(size: 6.5, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 3))
                            Text("break.toSkip")
                        }
                        .font(.system(size: 7.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                        .tracking(1)
                    }
                    .padding(.bottom, 14)
                } else {
                    // Horizon Layout: Title & timer centered, buttons at bottom
                    Spacer(minLength: 10)

                    // Center Hero Content (Title, Message, Timer)
                    VStack(spacing: 12) {
                        VStack(spacing: 4) {
                            Text("break.title")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.4), radius: 4, y: 1)

                            Text("break.message")
                                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.85))
                                .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                        }

                        Text("00:20")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.4), radius: 5, y: 2)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                    Spacer(minLength: 10)

                    // Bottom Action Buttons & ESC Hint
                    VStack(spacing: 8) {
                        HStack(spacing: 5) {
                            miniPill(title: "break.snooze", icon: "clock.arrow.circlepath")
                            miniPill(title: "break.skip", icon: "forward.end.fill")
                            miniPill(title: "break.lockScreen", icon: "lock.fill")
                        }

                        HStack(spacing: 3) {
                            Text("break.press")
                            Text("esc")
                                .font(.system(size: 6.5, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 3))
                            Text("break.toSkip")
                        }
                        .font(.system(size: 7.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                        .tracking(1)
                    }
                    .padding(.bottom, 16)
                }
            }
        }
        .frame(height: 330)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
    }

    private func miniPill(title: LocalizedStringKey, icon: String) -> some View {
        HStack(spacing: 3.5) {
            Image(systemName: icon)
                .font(.system(size: 7.5, weight: .bold))
            Text(title)
                .font(.system(size: 8, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 3.5)
        .background(Color.black.opacity(0.42), in: Capsule())
        .overlay {
            Capsule().stroke(.white.opacity(0.22), lineWidth: 0.5)
        }
    }
}
