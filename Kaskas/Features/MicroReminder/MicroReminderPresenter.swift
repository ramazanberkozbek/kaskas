import AppKit
import SwiftUI

@MainActor
final class MicroReminderPresenter {
    private static let maximumDisplayDuration: Duration = .seconds(6)

    private var panel: NonactivatingPanel?
    private var dismissalTask: Task<Void, Never>?

    func show(mascot: MicroReminderMascot, color: MicroReminderColor) {
        dismiss()

        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
            ?? NSScreen.main
            ?? NSScreen.screens.first else {
            return
        }

        let contentView = NSHostingView(rootView: MicroReminderView(mascot: mascot, color: color) { [weak self] in
            self?.dismiss()
        })
        contentView.frame = NSRect(origin: .zero, size: screen.frame.size)

        let panel = NonactivatingPanel(
            contentRect: contentView.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = contentView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .screenSaver
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        panel.setFrame(screen.frame, display: true)
        panel.orderFrontRegardless()
        self.panel = panel

        dismissalTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: Self.maximumDisplayDuration)
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
}

private final class NonactivatingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func mouseDown(with event: NSEvent) {}
    override func rightMouseDown(with event: NSEvent) {}
    override func otherMouseDown(with event: NSEvent) {}
}
