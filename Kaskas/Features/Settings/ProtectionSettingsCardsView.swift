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
            notificationButton
            Rectangle()
                .fill(.primary.opacity(0.10))
                .frame(width: 1, height: 20)
                .padding(.horizontal, 2)
            Toggle(title, isOn: $isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.vertical, 16)
    }

    private var notificationButton: some View {
        Button {
            indicatorEnabled.toggle()
            showsPreview = indicatorEnabled && isEnabled
        } label: {
            HStack(spacing: 5) {
                Image(systemName: indicatorEnabled ? "bell.fill" : "bell.slash")
                    .font(.system(size: 10, weight: .semibold))
                Text(indicatorEnabled ? "settings.protection.notification.on" : "settings.protection.notification.off")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(indicatorEnabled ? Color.accentColor : .secondary)
            .frame(minWidth: 48, minHeight: 28)
            .padding(.horizontal, 7)
            .background(indicatorEnabled ? Color.accentColor.opacity(0.10) : Color.primary.opacity(0.025),
                        in: RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(indicatorEnabled ? Color.accentColor.opacity(0.35) : Color.primary.opacity(0.12), lineWidth: 0.8)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityLabel("settings.protection.cursorEffect")
        .accessibilityValue(Text(indicatorEnabled ? "settings.protection.notification.on" : "settings.protection.notification.off"))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.18)) { showsPreview = hovering && isEnabled }
        }
        .onChange(of: isEnabled) { _, enabled in
            if !enabled { showsPreview = false }
        }
        .background(ProtectionHoverPreview(isPresented: showsPreview, indicatorEnabled: indicatorEnabled, typingPreview: typingPreview))
    }
}

// A native popover consumes its outside click before the underlying button can
// act. This nonactivating, mouse-transparent child panel behaves like a tooltip:
// hovering previews the effect, while the first click still toggles the setting.
private struct ProtectionHoverPreview: NSViewRepresentable {
    let isPresented: Bool
    let indicatorEnabled: Bool
    var typingPreview = false

    func makeNSView(context: Context) -> ProtectionPreviewAnchor { ProtectionPreviewAnchor() }

    func updateNSView(_ view: ProtectionPreviewAnchor, context: Context) {
        view.update(isPresented: isPresented, indicatorEnabled: indicatorEnabled, typingPreview: typingPreview)
    }

    static func dismantleNSView(_ view: ProtectionPreviewAnchor, coordinator: ()) { view.dismiss() }
}

private final class ProtectionPreviewAnchor: NSView {
    private var panel: NSPanel?
    private var presented = false
    private var indicatorEnabled = false
    private var typingPreview = false

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func update(isPresented: Bool, indicatorEnabled: Bool, typingPreview: Bool) {
        self.typingPreview = typingPreview
        presented = isPresented
        self.indicatorEnabled = indicatorEnabled
        guard isPresented else { dismiss(); return }
        showIfNeeded()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { dismiss() } else if presented { showIfNeeded() }
    }

    override func layout() {
        super.layout()
        positionPanel()
    }

    private func showIfNeeded() {
        guard let window else { return }
        if let panel {
            (panel.contentView as? NSHostingView<ProtectionNotificationPreview>)?.rootView =
                ProtectionNotificationPreview(indicatorEnabled: indicatorEnabled, typingPreview: typingPreview)
            positionPanel()
            return
        }
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 284, height: 228),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.contentView = NSHostingView(rootView: ProtectionNotificationPreview(indicatorEnabled: indicatorEnabled, typingPreview: typingPreview))
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = true
        panel.isReleasedWhenClosed = false
        self.panel = panel
        window.addChildWindow(panel, ordered: .above)
        positionPanel()
        panel.orderFront(nil)
    }

    private func positionPanel() {
        guard let panel, let window, let screen = window.screen else { return }
        let anchor = window.convertToScreen(convert(bounds, to: nil))
        let area = screen.visibleFrame
        let size = panel.frame.size
        let x = min(max(anchor.maxX - size.width, area.minX), area.maxX - size.width)
        let above = anchor.maxY + 8
        let y = above + size.height <= area.maxY ? above : max(area.minY, anchor.minY - size.height - 8)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func dismiss() {
        guard let panel else { return }
        panel.parent?.removeChildWindow(panel)
        panel.orderOut(nil)
        self.panel = nil
    }
}

private struct ProtectionNotificationPreview: View {
    let indicatorEnabled: Bool
    var typingPreview = false
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ProtectionCursorPreview(indicatorEnabled: indicatorEnabled, typingPreview: typingPreview)
                .frame(width: 260)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text("settings.protection.cursorEffect")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 5)
        .onAppear {
            withAnimation(.easeOut(duration: 0.18)) { appeared = true }
        }
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
