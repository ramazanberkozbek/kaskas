import Combine
import SwiftUI

struct MenuBarAppearanceSettingsView: View {
    let controller: SessionController

    @State private var now = Date.now
    @Environment(\.locale) private var locale

    private let clock = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        Section {
            VStack(spacing: 5) {
                ForEach(MenuBarDisplayMode.allCases) { mode in
                    option(mode)
                }

                Divider().padding(.top, 4)
                preview
                    .padding(.top, 8)
            }
            .padding(7)
        } header: {
            VStack(alignment: .leading, spacing: 4) {
                Text("settings.menuBar.title")
                    .font(.caption.weight(.bold))
                Text("settings.menuBar.subtitle")
                    .font(.callout)
                    .textCase(nil)
            }
        }
        .onReceive(clock) { now = $0 }
    }

    private func option(_ mode: MenuBarDisplayMode) -> some View {
        let selected = controller.configuration.menuBarDisplayMode == mode
        return Button {
            var configuration = controller.configuration
            configuration.menuBarDisplayMode = mode
            controller.updateConfiguration(configuration)
        } label: {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary.opacity(0.55))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(mode.titleKey)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(mode.descriptionKey)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                selected ? Color.accentColor.opacity(0.08) : .clear,
                in: RoundedRectangle(cornerRadius: 11)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11)
                    .strokeBorder(selected ? Color.accentColor.opacity(0.55) : .clear, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(selected ? Text("settings.menuBar.selected") : Text("settings.menuBar.notSelected"))
    }

    private var preview: some View {
        let mode = controller.configuration.menuBarDisplayMode
        return VStack(alignment: .leading, spacing: 8) {
            Text("settings.menuBar.preview")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

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
            .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.primary.opacity(0.08)))
            .accessibilityLabel("settings.menuBar.preview")
        }
        .padding(.horizontal, 9)
        .padding(.bottom, 4)
    }
}

private extension MenuBarDisplayMode {
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
