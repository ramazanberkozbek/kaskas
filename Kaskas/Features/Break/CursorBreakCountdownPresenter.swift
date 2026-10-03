import AppKit
import SwiftUI

@MainActor
final class CursorBreakCountdownPresenter {
    private var panel: NSPanel?
    private var trackingTimer: Timer?

    func show(endsAt: Date, leadTime: TimeInterval) {
        dismiss()
        guard endsAt > .now, !NSScreen.screens.isEmpty else { return }

        let size = CursorBreakCountdownView.panelSize
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        let contentView = NSHostingView(rootView: CursorBreakCountdownView(endsAt: endsAt, leadTime: leadTime))
        contentView.frame = NSRect(origin: .zero, size: size)
        panel.contentView = contentView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) + 1)
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .transient]
        panel.isReleasedWhenClosed = false

        self.panel = panel
        movePanelToCursor()
        panel.orderFrontRegardless()

        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if Date.now >= endsAt {
                    self.dismiss()
                } else {
                    self.movePanelToCursor()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        trackingTimer = timer
    }

    func dismiss() {
        trackingTimer?.invalidate()
        trackingTimer = nil
        panel?.orderOut(nil)
        panel = nil
    }

    private func movePanelToCursor() {
        guard let panel else { return }
        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) })
            ?? NSScreen.main else { return }

        let size = CursorBreakCountdownView.panelSize
        let gap: CGFloat = 16
        let x = pointer.x + size.width + gap <= screen.frame.maxX
            ? pointer.x + gap
            : pointer.x - size.width - gap
        let y = pointer.y + size.height + gap <= screen.frame.maxY
            ? pointer.y + gap
            : pointer.y - size.height - gap
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        if !panel.isVisible { panel.orderFrontRegardless() }
    }
}

private struct CursorBreakCountdownView: View {
    static let panelSize = CGSize(width: 142, height: 42)

    let endsAt: Date
    let leadTime: TimeInterval

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { context in
            let remaining = max(0, endsAt.timeIntervalSince(context.date))
            let seconds = Int(remaining.rounded(.up))
            let progress = min(1, remaining / leadTime)

            HStack(spacing: 7) {
                Circle()
                    .stroke(.white.opacity(0.25), lineWidth: 2)
                    .overlay {
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 27, height: 27)

                Text(seconds.formatted())
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()

                Text("•")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.42))

                Text("menu.break")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .frame(width: Self.panelSize.width, height: Self.panelSize.height)
            .modifier(NotificationGlassBackground(cornerRadius: Self.panelSize.height / 2))
        }
    }
}
