import AppKit
import SwiftUI

struct ProtectionSettingsCardsView: View {
    let controller: SessionController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("settings.protection.triggers.description")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            VStack(spacing: 0) {
                ProtectionTriggerRow(
                    title: "settings.protection.meeting.rowTitle",
                    subtitle: "settings.protection.meeting.rowSubtitle",
                    symbol: "phone.fill",
                    tint: .purple,
                    isEnabled: binding(for: \.pauseDuringMeetings),
                    indicatorEnabled: binding(for: \.meetingPauseIndicatorEnabled)
                )
                Divider()
                ProtectionTriggerRow(
                    title: "settings.protection.video.rowTitle",
                    subtitle: "settings.protection.video.rowSubtitle",
                    symbol: "play.fill",
                    tint: .cyan,
                    isEnabled: binding(for: \.pauseDuringVideo),
                    indicatorEnabled: binding(for: \.videoPauseIndicatorEnabled)
                )
                Divider()
                ProtectionTriggerRow(
                    title: "settings.protection.typing.rowTitle",
                    subtitle: "settings.protection.typing.rowSubtitle",
                    symbol: "keyboard",
                    tint: .pink,
                    isEnabled: binding(for: \.pauseWhileTyping),
                    indicatorEnabled: binding(for: \.typingPauseIndicatorEnabled),
                    typingPreview: true
                )
            }
        }
    }

    private func binding(for keyPath: WritableKeyPath<FocusConfiguration, Bool>) -> Binding<Bool> {
        Binding { controller.configuration[keyPath: keyPath] } set: { value in
            var configuration = controller.configuration
            configuration[keyPath: keyPath] = value
            controller.updateConfiguration(configuration)
        }
    }
}

private struct ProtectionTriggerRow: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let symbol: String
    let tint: Color
    @Binding var isEnabled: Bool
    @Binding var indicatorEnabled: Bool
    var typingPreview = false
    @State private var showsPreview = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            NotificationIndicatorToggleButton(
                isOn: $indicatorEnabled,
                isEnabled: isEnabled,
                accessibilityLabelKey: "settings.protection.cursorEffect",
                showsPreview: $showsPreview
            )
            .settingsHoverPreview(isPresented: showsPreview, size: CGSize(width: 284, height: 228)) {
                SettingsPreviewContainer(captionKey: "settings.protection.cursorEffect") {
                    ProtectionCursorPreview(indicatorEnabled: indicatorEnabled, typingPreview: typingPreview)
                        .frame(width: 260)
                }
            }

            SettingsVerticalDivider()

            Toggle(title, isOn: $isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.vertical, 16)
    }
}

private struct ProtectionCursorPreview: View {
    let indicatorEnabled: Bool
    var typingPreview = false
    @State private var wallpaper = DesktopWallpaperPreview.protection



    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = wallpaper.image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    LinearGradient(
                        colors: [Color(red: 0.18, green: 0.30, blue: 0.50), Color(red: 0.42, green: 0.30, blue: 0.44)],
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    )
                }
                Color.black.opacity(0.08)
                HStack(alignment: .center, spacing: 10) {
                    ZStack {
                        if indicatorEnabled {
                            if typingPreview { CursorTypingPauseView() }
                            else { CursorMeetingPauseView(repeats: true) }
                        }
                    }
                    .frame(width: typingPreview ? CursorTypingPauseView.panelSize.width : CursorMeetingPauseView.panelSize.width,
                           height: typingPreview ? CursorTypingPauseView.panelSize.height : CursorMeetingPauseView.panelSize.height)
                    SettingsCursorArrow()
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .frame(height: 180)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task { await wallpaper.load() }
    }
}
