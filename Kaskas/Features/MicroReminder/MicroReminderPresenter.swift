import AppKit
import SwiftUI

@MainActor
final class MicroReminderPresenter {
    private static let maximumDisplayDuration: Duration = .seconds(6)
    private static let escapeHintShownKey = "microReminderEscapeHintShown"
    private let defaults: UserDefaults
    private(set) var showsEscapeHint = false

    private var fullscreenPanel: NonactivatingPanel?
    private let cursorPresenter = CursorBreakCountdownPresenter()
    var panel: NSPanel? { fullscreenPanel ?? cursorPresenter.panel }
    private var dismissalTask: Task<Void, Never>?
    private var isShowingPreview = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func show(displayMode: MicroReminderDisplayMode = .mascot,
              mascot: MicroReminderMascot, color: MicroReminderColor, commitmentMode: MicroReminderCommitmentMode = .flexible, isPreview: Bool = false) {
        dismiss()
        if displayMode == .cursorIcon {
            cursorPresenter.showMicroReminder(color: color)
            isShowingPreview = isPreview
            return
        }

        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
            ?? NSScreen.main
            ?? NSScreen.screens.first else {
            return
        }

        showsEscapeHint = commitmentMode.allowsSkipping && !defaults.bool(forKey: Self.escapeHintShownKey)
        let contentView = NSHostingView(rootView: MicroReminderView(mascot: mascot, color: color, commitmentMode: commitmentMode, showsEscapeHint: showsEscapeHint) { [weak self] in
            self?.dismiss()
        })
        contentView.frame = NSRect(origin: .zero, size: screen.frame.size)

        let panel = NonactivatingPanel(
            contentRect: contentView.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.onSkip = commitmentMode.allowsSkipping ? { [weak self] in
            self?.dismiss()
        } : nil
        panel.contentView = contentView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .screenSaver
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .transient]

        panel.setFrame(screen.frame, display: true)
        panel.orderFrontRegardless()
        if commitmentMode.allowsSkipping { panel.makeKey() }
        self.fullscreenPanel = panel
        isShowingPreview = isPreview
        if showsEscapeHint { defaults.set(true, forKey: Self.escapeHintShownKey) }

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
        fullscreenPanel?.orderOut(nil)
        fullscreenPanel = nil
        cursorPresenter.dismiss()
        isShowingPreview = false
        showsEscapeHint = false
    }

    func dismissPreview() {
        if isShowingPreview { dismiss() }
    }
}

private final class NonactivatingPanel: NSPanel {
    var onSkip: (() -> Void)?
    override var canBecomeKey: Bool { onSkip != nil }

    override func cancelOperation(_ sender: Any?) { onSkip?() }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53, let onSkip {
            onSkip()
        } else {
            super.keyDown(with: event)
        }
    }
    override var canBecomeMain: Bool { false }

    override func mouseDown(with event: NSEvent) { onSkip?() }
    override func rightMouseDown(with event: NSEvent) {}
    override func otherMouseDown(with event: NSEvent) {}
}
