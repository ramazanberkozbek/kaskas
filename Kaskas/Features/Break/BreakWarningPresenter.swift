import AppKit
import SwiftUI

@MainActor
final class BreakWarningPresenter {
    private var panel: NSPanel?
    private var presentedEndDate: Date?
    private var dismissedEndDate: Date?
    private var isShowingPreview = false
    private var dismissalTask: Task<Void, Never>?
    private let cursorCountdown = CursorBreakCountdownPresenter()

    func show(
        endsAt: Date,
        leadTime: TimeInterval,
        position: NotificationPosition,
        isPreview: Bool = false,
        onStart: @escaping () -> Void,
        onPostpone: @escaping (TimeInterval) -> Void,
        onSkip: @escaping () -> Void
    ) {
        if !isPreview, dismissedEndDate == endsAt { return }
        if panel?.isVisible == true, presentedEndDate == endsAt, !isPreview { return }
        dismiss()

        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
            ?? NSScreen.main
            ?? NSScreen.screens.first else { return }

        let size = BreakWarningView.panelSize
        let x: CGFloat
        switch position {
        case .left: x = screen.visibleFrame.minX + 24
        case .center: x = screen.visibleFrame.midX - size.width / 2
        case .right: x = screen.visibleFrame.maxX - size.width - 24
        }
        let frame = NSRect(
            x: x,
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
            leadTime: leadTime,
            onStart: onStart,
            onPostpone: onPostpone,
            onSkip: onSkip
        ))
        contentView.frame = NSRect(origin: .zero, size: size)
        panel.contentView = contentView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .transient]
        panel.isReleasedWhenClosed = false
        panel.orderFrontRegardless()
        panel.makeKey()

        self.panel = panel
        presentedEndDate = endsAt
        isShowingPreview = isPreview
        cursorCountdown.show(endsAt: endsAt, leadTime: leadTime)

        dismissalTask = Task { @MainActor [weak self] in
            let displayTime = max(0, endsAt.timeIntervalSinceNow)
            do { try await Task.sleep(for: .seconds(displayTime)) } catch { return }
            guard let self, self.presentedEndDate == endsAt else { return }
            if !isPreview { self.dismissedEndDate = endsAt }
            self.dismiss()
        }
    }

    func dismiss() {
        dismissalTask?.cancel()
        dismissalTask = nil
        cursorCountdown.dismiss()
        panel?.orderOut(nil)
        panel = nil
        presentedEndDate = nil
        isShowingPreview = false
    }

    func dismissPreview() {
        if isShowingPreview { dismiss() }
    }

    func suppress(endsAt: Date) {
        dismissedEndDate = endsAt
    }
}

private final class BreakWarningPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
