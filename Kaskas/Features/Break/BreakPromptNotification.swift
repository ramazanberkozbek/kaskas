import AppKit
import SwiftUI

// MARK: - Prompt Configuration

struct BreakPromptConfiguration {
    let iconName: String
    let title: LocalizedStringKey
    let message: Text
    let primaryButtonTitle: LocalizedStringKey
    let secondaryButtonTitle: LocalizedStringKey
    let displayDuration: TimeInterval
    let accentColor: Color

    static func idle(duration: TimeInterval) -> Self {
        let minutes = Int64(max(1, Int(duration / 60)))
        return Self(
            iconName: "cup.and.saucer.fill",
            title: "idle.title",
            message: Text(String(format: String(localized: "idle.question"), minutes)),
            primaryButtonTitle: "idle.accept",
            secondaryButtonTitle: "idle.decline",
            displayDuration: 13,
            accentColor: Color(red: 1, green: 0.69, blue: 0.2)
        )
    }

    static var skippedBreak: Self {
        Self(
            iconName: "clock.arrow.circlepath",
            title: "skippedBreak.title",
            message: Text("skippedBreak.subtitle"),
            primaryButtonTitle: "skippedBreak.start",
            secondaryButtonTitle: "skippedBreak.dismiss",
            displayDuration: 10,
            accentColor: Color(red: 1, green: 0.69, blue: 0.2)
        )
    }
}

// MARK: - Reusable Presenter

@MainActor
final class BreakPromptPresenter {
    fileprivate static let panelSize = CGSize(width: 460, height: 166)

    private var panel: NSPanel?
    private var dismissalTask: Task<Void, Never>?

    func show(
        configuration: BreakPromptConfiguration,
        onPrimaryAction: @escaping () -> Void,
        onSecondaryAction: @escaping () -> Void = {}
    ) {
        dismiss()

        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) })
            ?? NSScreen.main ?? NSScreen.screens.first else { return }

        let size = Self.panelSize
        let frame = NSRect(
            x: screen.visibleFrame.midX - size.width / 2,
            y: screen.visibleFrame.maxY - size.height - 24,
            width: size.width,
            height: size.height
        )
        let expiresAt = Date.now.addingTimeInterval(configuration.displayDuration)
        let panel = BreakPromptPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        let handleSecondary = { [weak self] in
            self?.dismiss()
            onSecondaryAction()
        }

        panel.contentView = NonactivatingHostingView(rootView: BreakPromptView(
            configuration: configuration,
            expiresAt: expiresAt,
            onPrimaryAction: { [weak self] in
                self?.dismiss()
                onPrimaryAction()
            },
            onSecondaryAction: handleSecondary
        ))
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .transient]
        panel.isReleasedWhenClosed = false
        panel.orderFrontRegardless()
        self.panel = panel

        dismissalTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(configuration.displayDuration))
            guard !Task.isCancelled else { return }
            handleSecondary()
        }
    }

    func dismiss() {
        dismissalTask?.cancel()
        dismissalTask = nil
        panel?.orderOut(nil)
        panel = nil
    }
}

// MARK: - Reusable Prompt View

private struct BreakPromptView: View {
    let configuration: BreakPromptConfiguration
    let expiresAt: Date
    let onPrimaryAction: () -> Void
    let onSecondaryAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: configuration.iconName)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(configuration.accentColor)
                    .frame(width: 54, height: 54)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.14))
                            .allowsHitTesting(false)
                    }

                VStack(alignment: .leading, spacing: 5) {
                    Text(configuration.title)
                        .font(NotificationTypography.title())
                        .foregroundStyle(.white)

                    configuration.message
                        .font(NotificationTypography.message())
                        .foregroundStyle(.white.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                Button(action: onPrimaryAction) {
                    Text(configuration.primaryButtonTitle)
                        .font(NotificationTypography.action())
                        .padding(.horizontal, 17)
                        .frame(height: 36)
                        .background(.white.opacity(0.2), in: Capsule())
                        .contentShape(Capsule())
                }

                Button(action: onSecondaryAction) {
                    Text(configuration.secondaryButtonTitle)
                        .font(NotificationTypography.action())
                        .padding(.horizontal, 17)
                        .frame(height: 36)
                        .overlay { Capsule().stroke(.white.opacity(0.25)) }
                        .contentShape(Capsule())
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
        }
        .padding(20)
        .frame(width: BreakPromptPresenter.panelSize.width, height: BreakPromptPresenter.panelSize.height, alignment: .leading)
        .modifier(NotificationGlassBackground(cornerRadius: 20))
        .overlay {
            CountdownBorder(
                endsAt: expiresAt,
                duration: configuration.displayDuration,
                cornerRadius: 20,
                color: configuration.accentColor
            )
        }
    }
}

// MARK: - Domain Notifiers (SessionController Adapters)

@MainActor
final class IdleBreakNotifier {
    private let presenter = BreakPromptPresenter()

    func show(duration: TimeInterval, onAccept: @escaping () -> Void, onDecline: @escaping () -> Void) {
        presenter.show(
            configuration: .idle(duration: duration),
            onPrimaryAction: onAccept,
            onSecondaryAction: onDecline
        )
    }

    func dismiss() {
        presenter.dismiss()
    }
}

@MainActor
final class SkippedBreakNotifier {
    private let presenter = BreakPromptPresenter()

    func show(onStart: @escaping () -> Void) {
        presenter.show(
            configuration: .skippedBreak,
            onPrimaryAction: onStart
        )
    }

    func dismiss() {
        presenter.dismiss()
    }
}

private final class BreakPromptPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class NonactivatingHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}
