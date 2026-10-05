import AppKit
import SwiftUI

@MainActor
final class BreakWarningPresenter {
    private(set) var panel: NSPanel?
    private var presentedEndDate: Date?
    private var presentedPausedRemaining: TimeInterval?
    private var presentedTypingIndicator = true
    private var dismissedEndDate: Date?
    private var isShowingPreview = false
    private var dismissalTask: Task<Void, Never>?
    private let cursorCountdown = CursorBreakCountdownPresenter()

    func show(
        endsAt: Date,
        leadTime: TimeInterval,
        position: NotificationPosition,
        isPreview: Bool = false,
        pausedRemaining: TimeInterval? = nil,
        typingIndicatorEnabled: Bool = true,
        onStart: @escaping () -> Void,
        onPostpone: @escaping (TimeInterval) -> Void,
        onSkip: @escaping () -> Void
    ) {
        if !isPreview, dismissedEndDate == endsAt { return }
        if panel?.isVisible == true, presentedEndDate == endsAt,
           presentedPausedRemaining == pausedRemaining,
           presentedTypingIndicator == typingIndicatorEnabled, !isPreview { return }
        dismissalTask?.cancel()
        dismissalTask = nil

        let content = BreakWarningView(
            endsAt: endsAt,
            leadTime: leadTime,
            pausedRemaining: pausedRemaining,
            onStart: onStart,
            onPostpone: onPostpone,
            onSkip: onSkip
        )
        if let panel, panel.isVisible, isShowingPreview == isPreview,
           let hostingView = panel.contentView as? NonactivatingHostingView<BreakWarningView> {
            // Keep the window, glass surface, position and stacking order intact.
            // Only the countdown data changes when typing begins or ends.
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) { hostingView.rootView = content }
        } else {
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
            let contentView = NonactivatingHostingView(rootView: content)
            contentView.frame = NSRect(origin: .zero, size: size)
            panel.contentView = contentView
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.animationBehavior = .none
            panel.level = .statusBar
            panel.hidesOnDeactivate = false
            panel.collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .transient]
            panel.isReleasedWhenClosed = false
            panel.orderFrontRegardless()
            self.panel = panel
        }

        presentedEndDate = endsAt
        presentedPausedRemaining = pausedRemaining
        presentedTypingIndicator = typingIndicatorEnabled
        isShowingPreview = isPreview
        if pausedRemaining != nil {
            if typingIndicatorEnabled { cursorCountdown.showTypingPause() }
            else { cursorCountdown.dismiss() }
            return
        }
        cursorCountdown.show(endsAt: endsAt, leadTime: leadTime)

        dismissalTask = Task { @MainActor [weak self] in
            let displayTime = max(0, endsAt.timeIntervalSinceNow)
            do { try await Task.sleep(for: .seconds(displayTime)) } catch { return }
            guard !Task.isCancelled, let self, self.presentedEndDate == endsAt else { return }
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
        presentedPausedRemaining = nil
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
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class NonactivatingHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}
