import AppKit
import SwiftUI

@MainActor
final class MicroReminderPresenter {
    private var panel: NonactivatingPanel?
    private var dismissalTask: Task<Void, Never>?

    func show() {
        dismiss()

        let contentView = NSHostingView(rootView: MicroReminderView())
        contentView.frame = NSRect(
            origin: .zero,
            size: NSSize(width: Theme.Size.reminderWidth, height: Theme.Size.reminderHeight)
        )

        let panel = NonactivatingPanel(
            contentRect: contentView.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = contentView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        position(panel)
        panel.orderFrontRegardless()
        self.panel = panel

        dismissalTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(7))
            } catch {
                return
            }
            self?.dismiss()
        }
    }

    func dismiss() {
        dismissalTask?.cancel()
        dismissalTask = nil
        panel?.orderOut(nil)
        panel = nil
    }

    private func position(_ panel: NSPanel) {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSApp.keyWindow?.screen
            ?? NSScreen.screens.first { $0.frame.contains(mouseLocation) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let visibleFrame = screen?.visibleFrame else {
            return
        }

        let origin = NSPoint(
            x: visibleFrame.maxX - panel.frame.width - Theme.Size.windowInset,
            y: visibleFrame.minY + Theme.Size.windowInset
        )
        panel.setFrameOrigin(origin)
    }
}

private final class NonactivatingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
