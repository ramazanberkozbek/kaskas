import AppKit
import SwiftUI

struct AlertsSettingsView: View {
    let controller: SessionController

    @Environment(\.colorScheme) private var colorScheme

    private let leadTimes: [TimeInterval] = [5, 10, 20, 30, 60]

    private let reminderIntervals: [TimeInterval] = [5, 10, 20, 30].map { $0 * 60 }
    @State private var showingMascotPicker = false
    @State private var previewMascotKey = UUID()
    @State private var isMascotPreviewVisible = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsPageLayout.sectionSpacing) {
                SettingsPaneHeader(title: "settings.sidebar.notifications")

                // Preview and break warning toggle
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("settings.alerts.preview")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                        Spacer()
                        Toggle("settings.alerts.breakWarning", isOn: binding(for: \.breakWarningEnabled))
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .accessibilityLabel(Text("settings.alerts.breakWarning"))
                    }

                    NotificationDesktopPreview(
                        leadTime: controller.configuration.breakWarningLeadTime,
                        position: controller.configuration.notificationPosition,
                        isEnabled: controller.configuration.breakWarningEnabled,
                        breakBackground: controller.configuration.breakBackground,
                        customWallpaperPath: controller.configuration.customWallpaperPath
                    )
                }

                // Notification settings
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("settings.alerts.notificationSettings")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text("settings.alerts.notificationSettings.description")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 0) {
                        settingRow(
                            title: "settings.alerts.leadTime",
                            subtitle: "settings.alerts.leadTime.description"
                        ) {
                            SettingsDurationPicker(
                                title: "settings.alerts.leadTime",
                                selection: binding(for: \.breakWarningLeadTime),
                                options: leadTimes,
                                minimum: 5,
                                maximum: 60,
                                step: 5,
                                inputUnit: .seconds
                            )
                        }
                        .disabled(!controller.configuration.breakWarningEnabled)

                        Divider()
                            .padding(.horizontal, SettingsPageLayout.cardInset)

                        settingRow(
                            title: "settings.alerts.position",
                            subtitle: "settings.alerts.position.description"
                        ) {
                            SettingsMenuPicker(
                                title: "settings.alerts.position",
                                selection: positionBinding,
                                selectedLabel: positionLabel
                            ) {
                                Text("settings.alerts.left").tag(NotificationPosition.left)
                                Text("settings.alerts.center").tag(NotificationPosition.center)
                                Text("settings.alerts.right").tag(NotificationPosition.right)
                            }
                        }
                        .disabled(!controller.configuration.breakWarningEnabled)
                    }
                    .background(cardBackground, in: RoundedRectangle(cornerRadius: 16))
                }

                // Break Sounds Section
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("settings.breakSound.title")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text("settings.breakSound.subtitle")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 0) {
                        soundPickerRow(
                            title: "settings.breakSound.startChoice",
                            subtitle: "settings.breakSound.enabledDescription",
                            selection: soundSelection(
                                enabled: \.breakSoundEnabled,
                                sound: \.breakSound
                            )
                        )

                        Divider().padding(.horizontal, SettingsPageLayout.cardInset)

                        soundPickerRow(
                            title: "settings.breakSound.endChoice",
                            subtitle: "settings.breakSound.endEnabledDescription",
                            selection: soundSelection(
                                enabled: \.breakEndSoundEnabled,
                                sound: \.breakEndSound
                            )
                        )
                    }
                    .background(cardBackground, in: RoundedRectangle(cornerRadius: 16))
                }

                // Micro Reminders & Mascot Section
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("settings.microReminders.title")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text("settings.reminderInterval.description")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 0) {
                        // Header Area: Artwork Background and Mascot Preview
                        ZStack {
                            MicroReminderArtwork()

                            MicroReminderMascotView(
                                mascot: controller.configuration.microReminderMascot,
                                color: controller.configuration.microReminderColor,
                                size: 110,
                                animated: isMascotPreviewVisible,
                                looping: true
                            )
                            .id(previewMascotKey)
                        }
                        .frame(height: 240)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .onScrollVisibilityChange(threshold: 0.1) { isVisible in
                            isMascotPreviewVisible = isVisible
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            previewMascotKey = UUID()
                        }
                        .overlay(alignment: .topTrailing) {
                            Button {
                                controller.previewMicroReminder()
                            } label: {
                                Image(systemName: "viewfinder")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.95))
                                    .frame(width: 32, height: 32)
                                    .background(.black.opacity(0.50), in: RoundedRectangle(cornerRadius: 8))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(.white.opacity(0.18), lineWidth: 1)
                                    }
                            }
                            .buttonStyle(.plain)
                            .padding(12)
                        }

                        Divider()

                        // Row 1: Reminder Interval
                        settingRow(
                            title: "settings.reminderInterval",
                            subtitle: "settings.reminderInterval.description"
                        ) {
                            SettingsDurationPicker(
                                title: "settings.reminderInterval",
                                selection: binding(for: \.microReminderInterval),
                                options: reminderIntervals
                            )
                        }

                        Divider().padding(.horizontal, SettingsPageLayout.cardInset)

                        // Row 2: Mascot Selection
                        settingRow(
                            title: "settings.microReminderDesign.sidekick",
                            subtitle: LocalizedStringKey(controller.configuration.microReminderMascot.titleKey)
                        ) {
                            Button {
                                showingMascotPicker = true
                            } label: {
                                MicroReminderMascotView(
                                    mascot: controller.configuration.microReminderMascot,
                                    color: controller.configuration.microReminderColor,
                                    size: 24,
                                    animated: false
                                )
                                .frame(width: 44, height: 34)
                                .background(
                                    Color.white.opacity(colorScheme == .dark ? 0.08 : 0.05),
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showingMascotPicker = true
                        }
                    }
                    .background(cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(colorScheme == .dark ? 0.12 : 0.08), lineWidth: 1)
                    }
                }
            }
            .settingsPageContent()
        }
        .scrollIndicators(.hidden)
        .background(colorScheme == .dark
            ? Color(red: 0.075, green: 0.075, blue: 0.075)
            : Color(nsColor: .windowBackgroundColor))
        .overlay {
            if showingMascotPicker {
                GeometryReader { geometry in
                    ZStack {
                        Color.black.opacity(0.68)
                            .onTapGesture { showingMascotPicker = false }

                        MascotWheelPicker(
                            mascot: controller.configuration.microReminderMascot,
                            color: controller.configuration.microReminderColor,
                            onSelectMascot: { newMascot in
                                var config = controller.configuration
                                config.microReminderMascot = newMascot
                                controller.updateConfiguration(config)
                            },
                            onSelectColor: { newColor in
                                var config = controller.configuration
                                config.microReminderColor = newColor
                                controller.updateConfiguration(config)
                            },
                            onClose: { showingMascotPicker = false },
                            availableSize: geometry.size
                        )
                    }
                    .ignoresSafeArea()
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showingMascotPicker)
    }

    private var cardBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.115, green: 0.115, blue: 0.115)
            : Color(nsColor: .controlBackgroundColor)
    }

    private func settingRow<Control: View>(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            control()
        }
        .frame(minHeight: 66)
        .padding(.horizontal, SettingsPageLayout.cardInset)
    }

    private func soundPickerRow(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        selection: Binding<BreakSound?>
    ) -> some View {
        settingRow(title: title, subtitle: subtitle) {
            HStack(spacing: 8) {
                if let currentSound = selection.wrappedValue {
                    Button {
                        BreakSoundPlayer.preview(currentSound)
                    } label: {
                        Image(systemName: "speaker.wave.2")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(width: 26, height: 26)
                            .background(Color.primary.opacity(0.06), in: Circle())
                    }
                    .buttonStyle(.plain)
                }

                SettingsMenuPicker(
                    title: title,
                    selection: selection,
                    selectedLabel: selection.wrappedValue.map { Text($0.rawValue) }
                        ?? Text("settings.breakSound.off")
                ) {
                    Text("settings.breakSound.off").tag(nil as BreakSound?)
                    ForEach(BreakSound.allCases) { sound in
                        Text(sound.rawValue).tag(Optional(sound))
                    }
                }
            }
        }
    }



    private func soundSelection(
        enabled enabledKeyPath: WritableKeyPath<FocusConfiguration, Bool>,
        sound soundKeyPath: WritableKeyPath<FocusConfiguration, BreakSound>
    ) -> Binding<BreakSound?> {
        Binding {
            let configuration = controller.configuration
            return configuration[keyPath: enabledKeyPath]
                ? configuration[keyPath: soundKeyPath] : nil
        } set: { newValue in
            var configuration = controller.configuration
            if let newValue {
                configuration[keyPath: enabledKeyPath] = true
                configuration[keyPath: soundKeyPath] = newValue
            } else {
                configuration[keyPath: enabledKeyPath] = false
            }
            controller.updateConfiguration(configuration)
        }
    }

    private var positionLabel: Text {
        switch controller.configuration.notificationPosition {
        case .left: Text("settings.alerts.left")
        case .center: Text("settings.alerts.center")
        case .right: Text("settings.alerts.right")
        }
    }

    private var positionBinding: Binding<NotificationPosition> {
        binding(for: \.notificationPosition)
    }

    private func binding<Value>(for keyPath: WritableKeyPath<FocusConfiguration, Value>) -> Binding<Value> {
        Binding {
            controller.configuration[keyPath: keyPath]
        } set: { value in
            var configuration = controller.configuration
            configuration[keyPath: keyPath] = value
            controller.updateConfiguration(configuration)
        }
    }
}

private struct NotificationDesktopPreview: View {
    let leadTime: TimeInterval
    let position: NotificationPosition
    let isEnabled: Bool
    var breakBackground: BreakBackground = .ocean
    var customWallpaperPath: String? = nil

    @State private var wallpaper = DesktopWallpaperPreview.shared

    var body: some View {
        ZStack(alignment: .top) {
            if let defaultDesktopImage = wallpaper.image {
                Image(nsImage: defaultDesktopImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 330)
                    .clipped()
            } else {
                BreakBackgroundView(
                    background: breakBackground,
                    customWallpaperPath: customWallpaperPath
                )
                .frame(maxWidth: .infinity)
                .frame(height: 330)
                .clipped()
            }

            HStack {
                Image(systemName: "apple.logo")
                Spacer()
                Image("Mascot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 13, height: 13)
                Image(systemName: "wifi")
                Image(systemName: "speaker.wave.2.fill")
                Image(systemName: "switch.2")
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, SettingsPageLayout.cardInset)
            .frame(height: 24)
            .background(.black.opacity(0.40))

            if isEnabled {
                MiniBreakWarningView(leadTime: leadTime)
                    .frame(maxWidth: .infinity, alignment: alignment)
                    .padding(.horizontal, 20)
                    .padding(.top, 42)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: position)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "bell.slash.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("settings.alerts.breakWarning")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 24)
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
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task { await wallpaper.load() }
    }

    private var alignment: Alignment {
        switch position {
        case .left: .leading
        case .center: .center
        case .right: .trailing
        }
    }
}

private struct MiniBreakWarningView: View {
    let leadTime: TimeInterval
    private let accent = Color(red: 1, green: 0.62, blue: 0.39)

    var body: some View {
        let seconds = Int(leadTime)
        let timeString = String(format: "%02d:%02d", seconds / 60, seconds % 60)

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(accent)
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(accent.opacity(0.7), lineWidth: 1)
                    }

                VStack(alignment: .leading, spacing: 1) {
                    Text(timeString)
                        .font(NotificationTypography.title(scale: 0.62))
                        .monospacedDigit()
                        .foregroundStyle(.white)

                    Text("warning.subtitle")
                        .font(NotificationTypography.message(scale: 0.65))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "xmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.white.opacity(0.35))
                    .frame(width: 14, height: 14)
                    .background(Color.white.opacity(0.04), in: Circle())
            }

            HStack(spacing: 3) {
                miniButton("warning.startNow", prominent: true)
                miniButton("warning.oneMinute")
                miniButton("warning.fiveMinutes")
                miniButton("warning.fifteenMinutes")
            }
        }
        .padding(9)
        .frame(width: 236)
        .modifier(NotificationGlassBackground(cornerRadius: 12))
        .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
    }

    private func miniButton(_ title: LocalizedStringKey, prominent: Bool = false) -> some View {
        Text(title)
            .font(NotificationTypography.action(scale: 0.62))
            .foregroundStyle(.white.opacity(prominent ? 1.0 : 0.85))
            .padding(.horizontal, 6)
            .frame(height: 18)
            .background(
                prominent ? Color.white.opacity(0.12) : Color.white.opacity(0.04),
                in: Capsule()
            )
            .overlay {
                Capsule().stroke(Color.white.opacity(prominent ? 0.24 : 0.15), lineWidth: 0.5)
            }
    }
}
