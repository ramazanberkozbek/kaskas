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
        let revealState = BreakRevealState()
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
    private var previouslyActiveApp: NSRunningApplication?

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

        // Capture frontmost app before break panels gain key window status,
        // so we can reliably return focus when the break concludes.
        if previouslyActiveApp == nil {
            if let frontmost = NSWorkspace.shared.frontmostApplication,
               frontmost.bundleIdentifier != Bundle.main.bundleIdentifier {
                previouslyActiveApp = frontmost
            }
        }

        // Replacing a break that is already on screen should not replay the reveal.
        let isReplacingVisibleBreak = presentation != nil && !panels.isEmpty
        dismissPanels()
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
        if isReplacingVisibleBreak {
            presentation?.revealState.isRevealed = true
        }
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

        let revealState = presentation?.revealState
        DispatchQueue.main.async {
            revealState?.isRevealed = true
        }
    }

    func dismiss() {
        if let presentation, !panels.isEmpty {
            let fadingPanels = panels
            fadingPanels.forEach { $0.ignoresMouseEvents = true }
            panels.removeAll()
            presentation.revealState.isRevealed = false
            DispatchQueue.main.asyncAfter(deadline: .now() + BreakTransitionTiming.dismissDuration) {
                fadingPanels.forEach { $0.orderOut(nil) }
            }
        }
        dismissPanels()
        restorePreviousAppFocus()
    }

    func dismissPreview() {
        if presentation?.isPreview == true { dismiss() }
    }

    private func dismissPanels() {
        if let screenChangeObserver {
            NotificationCenter.default.removeObserver(screenChangeObserver)
            self.screenChangeObserver = nil
        }
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
        screenLayout.removeAll()
        presentation = nil
    }

    private func restorePreviousAppFocus() {
        guard let app = previouslyActiveApp else { return }
        previouslyActiveApp = nil
        if !app.isTerminated {
            app.activate()
        }
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

        // Ensure the interactive break view is always assigned to the active main display
        // (NSScreen.main), preventing it from unintentionally rendering on a secondary monitor.
        let primaryScreen = screens.first(where: { $0 == NSScreen.main }) ?? screens.first
        var primaryPanel: BreakPanel?

        for screen in screens {
            let panel = BreakPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            panel.onEscape = presentation.onSkip
            if primaryPanel == nil && screen == primaryScreen {
                primaryPanel = panel
                panel.contentViewController = NSHostingController(rootView: BreakTransitionContainer(
                    revealState: presentation.revealState
                ) {
                    BreakView(
                        endsAt: presentation.endsAt,
                        configuration: presentation.configuration,
                        isPreview: presentation.isPreview,
                        onSnooze: presentation.onSnooze,
                        onSkip: presentation.onSkip,
                        onLockScreen: presentation.onLockScreen,
                        onOpenSettings: presentation.onOpenSettings
                    )
                }.environment(\.locale, presentation.configuration.appLanguage.locale))
            } else {
                panel.contentViewController = NSHostingController(rootView: BreakTransitionContainer(
                    revealState: presentation.revealState
                ) {
                    BreakBackgroundView(
                        background: presentation.configuration.breakBackground,
                        customWallpaperPath: presentation.configuration.customWallpaperPath
                    )
                })
            }
            // Transparent so the desktop shows through while the blur fades in.
            panel.isOpaque = false
            panel.hasShadow = false
            panel.backgroundColor = .clear
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications]
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.setFrame(screen.frame, display: true)
            panel.orderFrontRegardless()
            panels.append(panel)
        }

        (primaryPanel ?? panels.first)?.makeKey()
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
