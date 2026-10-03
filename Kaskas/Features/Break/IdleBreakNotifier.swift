import AppKit
import SwiftUI

@MainActor
final class IdleBreakNotifier {
    private static let displayDuration: TimeInterval = 13
    private var panel: NSPanel?
    private var dismissalTask: Task<Void, Never>?

    func show(duration: TimeInterval, onAccept: @escaping () -> Void, onDecline: @escaping () -> Void) {
        dismiss()
        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) })
            ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let size = IdleBreakNotificationView.panelSize
        let frame = NSRect(
            x: screen.visibleFrame.midX - size.width / 2,
            y: screen.visibleFrame.maxY - size.height - 24,
            width: size.width,
            height: size.height
        )
        let expiresAt = Date.now.addingTimeInterval(Self.displayDuration)
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        let decline = { [weak self] in
            self?.dismiss()
            onDecline()
        }
        panel.contentView = NSHostingView(rootView: IdleBreakNotificationView(
            duration: duration,
            expiresAt: expiresAt,
            displayDuration: Self.displayDuration,
            onAccept: { [weak self] in
                self?.dismiss()
                onAccept()
            },
            onDecline: decline
        ))
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .transient]
        panel.isReleasedWhenClosed = false
        panel.orderFrontRegardless()
        panel.makeKey()
        self.panel = panel

        dismissalTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.displayDuration))
            guard !Task.isCancelled else { return }
            decline()
        }
    }

    func dismiss() {
        dismissalTask?.cancel()
        dismissalTask = nil
        panel?.orderOut(nil)
        panel = nil
    }
}

private struct IdleBreakNotificationView: View {
    static let panelSize = CGSize(width: 460, height: 166)

    let duration: TimeInterval
    let expiresAt: Date
    let displayDuration: TimeInterval
    let onAccept: () -> Void
    let onDecline: () -> Void

    private let accent = Color(red: 1, green: 0.69, blue: 0.2)

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(accent)
                    .frame(width: 54, height: 54)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.14))
                            .allowsHitTesting(false)
                    }
                VStack(alignment: .leading, spacing: 5) {
                    Text("idle.title")
                        .font(NotificationTypography.title())
                        .foregroundStyle(.white)
                    Text(String(format: String(localized: "idle.question"), Int64(max(1, Int(duration / 60)))))
                        .font(NotificationTypography.message())
                        .foregroundStyle(.white.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                Button(action: onAccept) {
                    Text("idle.accept")
                        .font(NotificationTypography.action())
                        .padding(.horizontal, 17)
                        .frame(height: 36)
                        .background(.white.opacity(0.2), in: Capsule())
                }
                Button(action: onDecline) {
                    Text("idle.decline")
                        .font(NotificationTypography.action())
                        .padding(.horizontal, 17)
                        .frame(height: 36)
                        .overlay { Capsule().stroke(.white.opacity(0.25)) }
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
        }
        .padding(20)
        .frame(width: Self.panelSize.width, height: Self.panelSize.height, alignment: .leading)
        .modifier(NotificationGlassBackground(cornerRadius: 20))
        .overlay {
            CountdownBorder(endsAt: expiresAt, duration: displayDuration, cornerRadius: 20, color: accent)
        }
    }
}
