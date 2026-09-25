import AppKit
import SwiftUI

@MainActor
final class BreakWarningPresenter {
    private var panel: NSPanel?
    private var presentedEndDate: Date?

    func show(
        endsAt: Date,
        onStart: @escaping () -> Void,
        onPostpone: @escaping (TimeInterval) -> Void,
        onSkip: @escaping () -> Void
    ) {
        if panel?.isVisible == true, presentedEndDate == endsAt { return }
        dismiss()

        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
            ?? NSScreen.main
            ?? NSScreen.screens.first else { return }

        let size = NSSize(width: 600, height: 164)
        let frame = NSRect(
            x: screen.visibleFrame.midX - size.width / 2,
            y: screen.visibleFrame.maxY - size.height - 24,
            width: size.width,
            height: size.height
        )
        let panel = BreakWarningPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        let contentView = NSHostingView(rootView: BreakWarningView(
            endsAt: endsAt,
            onStart: onStart,
            onPostpone: onPostpone,
            onSkip: onSkip
        ))
        contentView.frame = NSRect(origin: .zero, size: size)
        panel.contentView = contentView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isReleasedWhenClosed = false
        panel.orderFrontRegardless()

        self.panel = panel
        presentedEndDate = endsAt
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
        presentedEndDate = nil
    }
}

private final class BreakWarningPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
