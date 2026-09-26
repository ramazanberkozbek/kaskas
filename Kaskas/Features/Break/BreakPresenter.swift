import AppKit
import SwiftUI

@MainActor
final class BreakPresenter {
    private var window: BreakPanel?
    private var presentedEndDate: Date?
    private var isShowingPreview = false

    func show(
        endsAt: Date,
        configuration: FocusConfiguration,
        isPreview: Bool = false,
        onSnooze: @escaping @MainActor () -> Void,
        onSkip: @escaping @MainActor () -> Void,
        onLockScreen: @escaping @MainActor () -> Void,
        onOpenSettings: @escaping @MainActor () -> Void
    ) {
        if window?.isVisible == true, presentedEndDate == endsAt {
            return
        }

        dismiss()

        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouseLocation) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else {
            return
        }

        let rootView = BreakView(
            endsAt: endsAt,
            configuration: configuration,
            isPreview: isPreview,
            onSnooze: onSnooze,
            onSkip: onSkip,
            onLockScreen: onLockScreen,
            onOpenSettings: onOpenSettings
        )
        let hostingController = NSHostingController(rootView: rootView)
        let window = BreakPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.onEscape = onSkip
        window.contentViewController = hostingController
        window.backgroundColor = .black
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications]
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.setFrame(screen.frame, display: true)

        window.orderFrontRegardless()
        window.makeKey()
        self.window = window
        presentedEndDate = endsAt
        isShowingPreview = isPreview

        if !isPreview, configuration.breakSoundEnabled {
            NSSound(named: NSSound.Name(configuration.breakSound.rawValue))?.play()
        }
    }

    func dismiss() {
        window?.orderOut(nil)
        window = nil
        presentedEndDate = nil
        isShowingPreview = false
    }

    func dismissPreview() {
        if isShowingPreview { dismiss() }
    }
}

private final class BreakPanel: NSPanel {
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC key
            onEscape?()
        } else {
            super.keyDown(with: event)
        }
    }
}
