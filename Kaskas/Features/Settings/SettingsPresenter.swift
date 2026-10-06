import AppKit
import SwiftUI

@MainActor
final class SettingsPresenter: NSObject, NSWindowDelegate {
    private var window: SettingsWindow?

    func show(controller: SessionController, pane: SettingsPane = .dashboard) {
        let trace = PerformanceTrace.begin("Settings window show")
        defer { PerformanceTrace.end(trace) }
        controller.targetSettingsPane = pane
        if let window {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            bringToFront(window)
            return
        }

        ensureMainMenu()

        let rootView = SettingsView(controller: controller, initialPane: pane)
        let hostingController = NSHostingController(rootView: rootView)
        // NSWindow owns this fixed-size window's dimensions. Asking SwiftUI
        // for minimum, ideal and maximum content sizes relays out every pane.
        hostingController.sizingOptions = []

        let window = SettingsWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: Theme.Size.settingsWidth,
                height: Theme.Size.settingsHeight
            ),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.contentViewController = hostingController
        window.appearance = controller.configuration.appAppearance.nsAppearance
        window.title = "Kaskas"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.tabbingMode = .disallowed
        window.setContentSize(NSSize(width: Theme.Size.settingsWidth, height: Theme.Size.settingsHeight))
        window.minSize = NSSize(width: Theme.Size.settingsWidth, height: Theme.Size.settingsHeight)
        window.maxSize = NSSize(width: Theme.Size.settingsWidth, height: Theme.Size.settingsHeight)
        window.center()

        self.window = window

        bringToFront(window)
    }

    func dismiss() {
        window?.orderOut(nil)
    }

    private func bringToFront(_ window: NSWindow) {
        window.makeKeyAndOrderFront(nil)

        DispatchQueue.main.async {
            NSApp.unhide(nil)
            NSRunningApplication.current.activate(options: .activateIgnoringOtherApps)
            window.makeKeyAndOrderFront(nil)
        }
    }

    func setDockVisibility(_ visible: Bool) {
        let policy: NSApplication.ActivationPolicy = visible ? .regular : .accessory
        guard NSApp.activationPolicy() != policy else { return }
        let visibleWindow = window.flatMap { $0.isVisible && !$0.isMiniaturized ? $0 : nil }
        if visible { ensureMainMenu() }
        guard NSApp.setActivationPolicy(policy) else { return }

        // Removing the Dock icon can deactivate/hide the app. Restore the
        // settings window after AppKit finishes the policy transition.
        if let visibleWindow {
            bringToFront(visibleWindow)
        }
    }

    // MARK: - Main Menu Support

    private func ensureMainMenu() {
        guard NSApp.mainMenu == nil else { return }
        let mainMenu = NSMenu()

        // App Menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: String(localized: "Kaskas Hakkında"), action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: String(localized: "Kaskas'ı Gizle"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = appMenu.addItem(withTitle: String(localized: "Diğerlerini Gizle"), action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: String(localized: "Tümünü Göster"), action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: String(localized: "menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // Edit Menu
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: String(localized: "Düzen"))
        editMenu.addItem(withTitle: String(localized: "Geri Al"), action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: String(localized: "Yinele"), action: Selector(("redo:")), keyEquivalent: "Z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: String(localized: "Kes"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: String(localized: "Kopyala"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: String(localized: "Yapıştır"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: String(localized: "Tümünü Seç"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // Window Menu
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: String(localized: "Pencere"))
        windowMenu.addItem(withTitle: String(localized: "Kapat"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: String(localized: "Simge Durumuna Küçült"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        NSApp.mainMenu = mainMenu
    }
}

private final class SettingsWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "w" {
            performClose(nil)
            return true
        }
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "q" {
            NSApp.terminate(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
