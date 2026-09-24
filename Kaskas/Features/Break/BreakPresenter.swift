import AppKit
import SwiftUI

@MainActor
final class BreakPresenter {
    private var window: BreakWindow?
    private var presentedEndDate: Date?

    func show(endsAt: Date, onComplete: @escaping @MainActor () -> Void) {
        if window?.isVisible == true, presentedEndDate == endsAt {
            return
        }

        dismiss()

        let mouseLocation = NSEvent.mouseLocation
        let screen = NSApp.keyWindow?.screen
            ?? NSScreen.screens.first { $0.frame.contains(mouseLocation) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else {
            return
        }

        let rootView = BreakView(endsAt: endsAt, onComplete: onComplete)
        let hostingController = NSHostingController(rootView: rootView)
        let window = BreakWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.contentViewController = hostingController
        window.backgroundColor = .windowBackgroundColor
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.setFrame(screen.frame, display: true)

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        self.window = window
        presentedEndDate = endsAt
    }

    func dismiss() {
        window?.orderOut(nil)
        window = nil
        presentedEndDate = nil
    }
}

private final class BreakWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
