import AppKit
import SwiftUI

// MARK: - Non-Activating Hover Popover Panel

// A native popover consumes its outside click before the underlying button can
// act. This nonactivating, mouse-transparent child panel behaves like a tooltip:
// hovering previews the effect, while the first click still toggles the setting.
struct SettingsHoverPreview<Content: View>: NSViewRepresentable {
    let isPresented: Bool
    let size: CGSize
    @ViewBuilder let content: () -> Content

    func makeNSView(context: Context) -> SettingsHoverPreviewAnchor<Content> {
        SettingsHoverPreviewAnchor(size: size, content: content)
    }

    func updateNSView(_ view: SettingsHoverPreviewAnchor<Content>, context: Context) {
        view.update(isPresented: isPresented, content: content)
    }

    static func dismantleNSView(_ view: SettingsHoverPreviewAnchor<Content>, coordinator: ()) {
        view.dismiss()
    }
}

final class SettingsHoverPreviewAnchor<Content: View>: NSView {
    private let size: CGSize
    private var content: () -> Content
    private var panel: NSPanel?
    private var presented = false

    init(size: CGSize, content: @escaping () -> Content) {
        self.size = size
        self.content = content
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func update(isPresented: Bool, content: @escaping () -> Content) {
        self.content = content
        presented = isPresented
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
            (panel.contentView as? NSHostingView<Content>)?.rootView = content()
            positionPanel()
            return
        }
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = NSHostingView(rootView: content())
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

extension View {
    func settingsHoverPreview<PreviewContent: View>(
        isPresented: Bool,
        size: CGSize,
        @ViewBuilder content: @escaping () -> PreviewContent
    ) -> some View {
        background(SettingsHoverPreview(isPresented: isPresented, size: size, content: content))
    }
}

// MARK: - Reusable Settings Preview Container

struct SettingsPreviewContainer<Content: View>: View {
    let captionKey: LocalizedStringKey
    @ViewBuilder let content: () -> Content
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text(captionKey)
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

// MARK: - Reusable Notification Indicator Button & Divider

struct NotificationIndicatorToggleButton: View {
    @Binding var isOn: Bool
    let isEnabled: Bool
    let accessibilityLabelKey: LocalizedStringKey
    @Binding var showsPreview: Bool

    var body: some View {
        Button {
            isOn.toggle()
            showsPreview = isOn && isEnabled
        } label: {
            HStack(spacing: 5) {
                Image(systemName: isOn ? "bell.fill" : "bell.slash")
                    .font(.system(size: 10, weight: .semibold))
                Text(isOn ? "settings.protection.notification.on" : "settings.protection.notification.off")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(isOn ? Color.accentColor : .secondary)
            .frame(minWidth: 48, minHeight: 28)
            .padding(.horizontal, 7)
            .background(
                isOn ? Color.accentColor.opacity(0.10) : Color.primary.opacity(0.025),
                in: RoundedRectangle(cornerRadius: 7)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(
                        isOn ? Color.accentColor.opacity(0.35) : Color.primary.opacity(0.12),
                        lineWidth: 0.8
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityLabel(accessibilityLabelKey)
        .accessibilityValue(Text(isOn ? "settings.protection.notification.on" : "settings.protection.notification.off"))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.18)) { showsPreview = hovering && isEnabled }
        }
        .onChange(of: isEnabled) { _, enabled in
            if !enabled { showsPreview = false }
        }
    }
}

struct SettingsVerticalDivider: View {
    var body: some View {
        Rectangle()
            .fill(.primary.opacity(0.10))
            .frame(width: 1, height: 20)
            .padding(.horizontal, 2)
    }
}
