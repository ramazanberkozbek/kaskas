import AppKit
import SwiftUI

@MainActor
final class BreakPresenter {
    private struct Presentation {
        let endsAt: Date
        let configuration: FocusConfiguration
        let isPreview: Bool
        let onSnooze: @MainActor () -> Void
        let onSkip: @MainActor () -> Void
        let onLockScreen: @MainActor () -> Void
        let onOpenSettings: @MainActor () -> Void
    }

    private struct ScreenLayout: Equatable {
        let number: Int?
        let frame: CGRect

        init(_ screen: NSScreen) {
            number = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.intValue
            frame = screen.frame
        }
    }

    private var panels: [BreakPanel] = []
    private var presentation: Presentation?
    private var screenLayout: [ScreenLayout] = []
    private var screenChangeObserver: NSObjectProtocol?

    func show(
        endsAt: Date,
        configuration: FocusConfiguration,
        isPreview: Bool = false,
        onSnooze: @escaping @MainActor () -> Void,
        onSkip: @escaping @MainActor () -> Void,
        onLockScreen: @escaping @MainActor () -> Void,
        onOpenSettings: @escaping @MainActor () -> Void
    ) {
        let screens = NSScreen.screens
        if let presentation,
           presentation.endsAt == endsAt,
           presentation.configuration == configuration,
           presentation.isPreview == isPreview {
            if screenLayout != screens.map(ScreenLayout.init) || !panels.allSatisfy(\.isVisible) {
                rebuildPanels(on: screens)
            }
            return
        }

        dismiss()
        guard !screens.isEmpty else { return }

        presentation = Presentation(
            endsAt: endsAt,
            configuration: configuration,
            isPreview: isPreview,
            onSnooze: onSnooze,
            onSkip: onSkip,
            onLockScreen: onLockScreen,
            onOpenSettings: onOpenSettings
        )
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateForScreenChanges()
            }
        }
        rebuildPanels(on: screens)

        if !isPreview, configuration.breakSoundEnabled {
            NSSound(named: NSSound.Name(configuration.breakSound.rawValue))?.play()
        }
    }

    func dismiss() {
        if let screenChangeObserver {
            NotificationCenter.default.removeObserver(screenChangeObserver)
            self.screenChangeObserver = nil
        }
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
        screenLayout.removeAll()
        presentation = nil
    }

    func dismissPreview() {
        if presentation?.isPreview == true { dismiss() }
    }

    private func updateForScreenChanges() {
        guard presentation != nil else { return }
        let screens = NSScreen.screens
        guard screenLayout != screens.map(ScreenLayout.init) else { return }
        rebuildPanels(on: screens)
    }

    private func rebuildPanels(on screens: [NSScreen]) {
        guard let presentation else { return }

        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
        screenLayout = screens.map(ScreenLayout.init)

        for (index, screen) in screens.enumerated() {
            let panel = BreakPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            panel.onEscape = presentation.onSkip
            if index == 0 {
                panel.contentViewController = NSHostingController(rootView: BreakView(
                    endsAt: presentation.endsAt,
                    configuration: presentation.configuration,
                    isPreview: presentation.isPreview,
                    onSnooze: presentation.onSnooze,
                    onSkip: presentation.onSkip,
                    onLockScreen: presentation.onLockScreen,
                    onOpenSettings: presentation.onOpenSettings
                ))
            } else {
                panel.contentViewController = NSHostingController(rootView: BreakBackgroundView(
                    background: presentation.configuration.breakBackground,
                    customWallpaperPath: presentation.configuration.customWallpaperPath
                ).ignoresSafeArea())
            }
            panel.backgroundColor = .black
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications]
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.setFrame(screen.frame, display: true)
            panel.orderFrontRegardless()
            panels.append(panel)
        }

        panels.first?.makeKey()
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
