import AppKit
import SwiftUI

@MainActor
final class SkippedBreakNotifier {
    private static let displayDuration: TimeInterval = 10

    private var panel: NSPanel?
    private var dismissalTask: Task<Void, Never>?

    func show(onStart: @escaping () -> Void) {
        dismiss()

        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) })
            ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let size = SkippedBreakNotificationView.panelSize
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
        panel.contentView = NSHostingView(rootView: SkippedBreakNotificationView(
            expiresAt: expiresAt,
            displayDuration: Self.displayDuration,
            onStart: { [weak self] in
                self?.dismiss()
                onStart()
            },
            onDismiss: { [weak self] in self?.dismiss() }
        ))
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .transient]
        panel.isReleasedWhenClosed = false
        panel.orderFrontRegardless()
        panel.makeKey()
        self.panel = panel

        dismissalTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(Self.displayDuration))
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    func dismiss() {
        dismissalTask?.cancel()
        dismissalTask = nil
        panel?.orderOut(nil)
        panel = nil
    }
}

private struct SkippedBreakNotificationView: View {
    static let panelSize = CGSize(width: 460, height: 166)

    let expiresAt: Date
    let displayDuration: TimeInterval
    let onStart: () -> Void
    let onDismiss: () -> Void

    private let accent = Color(red: 1, green: 0.69, blue: 0.2)

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(accent)
                    .frame(width: 54, height: 54)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.14))
                            .allowsHitTesting(false)
                    }

                VStack(alignment: .leading, spacing: 5) {
                    Text("skippedBreak.title")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("skippedBreak.subtitle")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                Button(action: onStart) {
                    Text("skippedBreak.start")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 17)
                        .frame(height: 36)
                        .background(.white.opacity(0.2), in: Capsule())
                        .contentShape(Capsule())
                }
                Button(action: onDismiss) {
                    Text("skippedBreak.dismiss")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 17)
                        .frame(height: 36)
                        .overlay { Capsule().stroke(.white.opacity(0.25)) }
                        .contentShape(Capsule())
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
        }
        .padding(20)
        .frame(width: Self.panelSize.width, height: Self.panelSize.height, alignment: .leading)
        .background(Color(red: 0.17, green: 0.16, blue: 0.17), in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            CountdownBorder(
                endsAt: expiresAt,
                duration: displayDuration,
                cornerRadius: 24,
                color: accent
            )
        }
        .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
    }
}
