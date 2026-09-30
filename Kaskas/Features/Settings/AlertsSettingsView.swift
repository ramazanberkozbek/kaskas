import AppKit
import SwiftUI

struct AlertsSettingsView: View {
    let controller: SessionController

    @Environment(\.colorScheme) private var colorScheme

    private let leadTimes: [TimeInterval] = [5, 10, 15, 20, 25, 30]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Önizleme ve mola uyarısı anahtarı
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("settings.alerts.preview")
                            .font(.system(size: 13, weight: .semibold))
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Toggle("settings.alerts.breakWarning", isOn: binding(for: \.breakWarningEnabled))
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .accessibilityLabel(Text("settings.alerts.breakWarning"))
                    }
                    .padding(.horizontal, 4)

                    NotificationDesktopPreview(
                        leadTime: controller.configuration.breakWarningLeadTime,
                        position: controller.configuration.notificationPosition,
                        isEnabled: controller.configuration.breakWarningEnabled
                    )
                }

                // Bildirim ayarları
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("settings.alerts.notificationSettings")
                            .font(.system(size: 13, weight: .semibold))
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary)
                        Text("settings.alerts.notificationSettings.description")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 4)

                    VStack(spacing: 0) {
                        settingRow(
                            title: "settings.alerts.leadTime",
                            subtitle: "settings.alerts.leadTime.description"
                        ) {
                            Picker("settings.alerts.leadTime", selection: binding(for: \.breakWarningLeadTime)) {
                                ForEach(leadTimes, id: \.self) { seconds in
                                    Text(secondsLabel(seconds)).tag(seconds)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(width: 140, alignment: .trailing)
                        }
                        .disabled(!controller.configuration.breakWarningEnabled)

                        Divider()
                            .padding(.leading, 16)

                        settingRow(
                            title: "settings.alerts.position",
                            subtitle: "settings.alerts.position.description"
                        ) {
                            Picker("settings.alerts.position", selection: binding(for: \.notificationPosition)) {
                                Text("settings.alerts.left").tag(NotificationPosition.left)
                                Text("settings.alerts.center").tag(NotificationPosition.center)
                                Text("settings.alerts.right").tag(NotificationPosition.right)
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(width: 140, alignment: .trailing)
                        }
                        .disabled(!controller.configuration.breakWarningEnabled)
                    }
                    .background(cardBackground, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .frame(maxWidth: 600, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 36)
        }
        .background(colorScheme == .dark
            ? Color(red: 0.075, green: 0.075, blue: 0.075)
            : Color(nsColor: .windowBackgroundColor))
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
        .padding(.horizontal, 16)
    }

    private func secondsLabel(_ seconds: TimeInterval) -> String {
        Measurement(value: seconds, unit: UnitDuration.seconds)
            .formatted(.measurement(width: .wide, usage: .asProvided))
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

    @State private var wallpaper = DesktopWallpaperPreview.shared

    var body: some View {
        ZStack(alignment: .top) {
            if let defaultDesktopImage = wallpaper.image {
                Image(nsImage: defaultDesktopImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
            } else {
                Color(nsColor: .windowBackgroundColor)
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
            .padding(.horizontal, 14)
            .frame(height: 22)
            .background(.black.opacity(0.45))

            if isEnabled {
                MiniBreakWarningView(leadTime: leadTime)
                    .frame(maxWidth: .infinity, alignment: alignment)
                    .padding(.horizontal, 14)
                    .padding(.top, 38)
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
                .padding(.top, 22)
            }
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
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

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(accent)
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    }

                VStack(alignment: .leading, spacing: 1) {
                    (Text("warning.title") + Text(" ") + Text(timeString))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)

                    Text("warning.subtitle")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                }
            }

            HStack(spacing: 4) {
                miniButton("warning.skip")
                miniButton("warning.oneMinute")
                miniButton("warning.fiveMinutes")
                Spacer(minLength: 0)
                miniButton("warning.startNow", prominent: true)
            }
        }
        .padding(12)
        .frame(width: 270)
        .background(Color(red: 0.15, green: 0.15, blue: 0.15), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(accent, lineWidth: 1.5)
        }
        .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
    }

    private func miniButton(_ title: LocalizedStringKey, prominent: Bool = false) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .frame(height: 22)
            .background(
                prominent ? Color.white.opacity(0.2) : Color.clear,
                in: Capsule()
            )
            .overlay {
                Capsule().stroke(Color.white.opacity(prominent ? 0 : 0.25), lineWidth: 0.75)
            }
    }
}
