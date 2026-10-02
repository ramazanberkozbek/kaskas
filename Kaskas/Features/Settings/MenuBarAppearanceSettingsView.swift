import Combine
import SwiftUI

struct MenuBarAppearanceSettingsView: View {
    let controller: SessionController

    @State private var now = Date.now
    @Environment(\.locale) private var locale

    private let clock = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    @State private var isHovered = false

    var body: some View {
        Section {
            preview
                .padding(4)
        } header: {
            VStack(alignment: .leading, spacing: 2) {
                Text("settings.menuBar.title")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .textCase(nil)
                Text("settings.menuBar.subtitle")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }
        }
        .onReceive(clock) { now = $0 }
    }

    private var preview: some View {
        let mode = controller.configuration.menuBarDisplayMode
        return Button(action: cycleMode) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("settings.menuBar.preview")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(mode.titleKey)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 16))
                    Spacer(minLength: 0)
                    HStack(spacing: 5) {
                        if mode != .timerOnly {
                            Image("Mascot")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                        }
                        if mode != .iconOnly {
                            Text(MenuBarDurationFormatter.string(
                                for: controller.snapshot(at: now).remaining,
                                locale: locale
                            ))
                            .monospacedDigit()
                        }
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                    Image(systemName: "wifi")
                    Image(systemName: "speaker.wave.2.fill")
                    Image(systemName: "switch.2")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary.opacity(0.78))
                .padding(.horizontal, 12)
                .frame(height: 42)
                .background(
                    isHovered ? Color.primary.opacity(0.08) : Color.primary.opacity(0.05),
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(isHovered ? Color.primary.opacity(0.2) : Color.primary.opacity(0.08))
                )
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PreviewButtonStyle())
        .onHover { isHovered = $0 }
        .accessibilityLabel("settings.menuBar.preview")
        .accessibilityValue(Text(mode.titleKey))
    }

    private func cycleMode() {
        withAnimation(.easeInOut(duration: 0.2)) {
            var configuration = controller.configuration
            configuration.menuBarDisplayMode = configuration.menuBarDisplayMode.next
            controller.updateConfiguration(configuration)
        }
    }
}

private struct PreviewButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

private extension MenuBarDisplayMode {
    var next: MenuBarDisplayMode {
        switch self {
        case .iconAndTimer: .iconOnly
        case .iconOnly: .timerOnly
        case .timerOnly: .iconAndTimer
        }
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .iconAndTimer: "settings.menuBar.iconAndTimer.title"
        case .iconOnly: "settings.menuBar.iconOnly.title"
        case .timerOnly: "settings.menuBar.timerOnly.title"
        }
    }

    var descriptionKey: LocalizedStringKey {
        switch self {
        case .iconAndTimer: "settings.menuBar.iconAndTimer.description"
        case .iconOnly: "settings.menuBar.iconOnly.description"
        case .timerOnly: "settings.menuBar.timerOnly.description"
        }
    }
}
