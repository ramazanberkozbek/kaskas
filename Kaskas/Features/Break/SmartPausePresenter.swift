import AppKit
import SwiftUI

@MainActor
final class SmartPausePresenter {
    private var panel: NSPanel?

    func show(onCountAsBreak: @escaping () -> Void, onIgnore: @escaping () -> Void) {
        guard panel == nil else { return }
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
            ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let size = SmartPauseView.panelSize
        let frame = NSRect(
            x: screen.visibleFrame.midX - size.width / 2,
            y: screen.visibleFrame.maxY - size.height - 24,
            width: size.width,
            height: size.height
        )
        let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.contentView = NSHostingView(rootView: SmartPauseView(
            onCountAsBreak: onCountAsBreak, onIgnore: onIgnore
        ))
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .transient]
        panel.orderFrontRegardless()
        panel.makeKey()
        self.panel = panel
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }
}
