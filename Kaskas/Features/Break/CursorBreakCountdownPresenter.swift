import AppKit
import SwiftUI

@MainActor
final class CursorBreakCountdownPresenter {
    private(set) var panel: NSPanel?
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var autoDismissTask: Task<Void, Never>?
    private var panelSize = CursorBreakCountdownView.panelSize

    func show(endsAt: Date, leadTime: TimeInterval) {
        show(
            content: AnyView(CursorBreakCountdownView(endsAt: endsAt, leadTime: leadTime)),
            size: CursorBreakCountdownView.panelSize,
            endsAt: endsAt
        )
    }

    func showMeetingPause() {
        show(
            content: AnyView(CursorMeetingPauseView()),
            size: CursorMeetingPauseView.panelSize,
            endsAt: .now.addingTimeInterval(CursorMeetingPauseView.displayDuration)
        )
    }

    func showTypingPause() {
        show(content: AnyView(CursorTypingPauseView()), size: CursorTypingPauseView.panelSize,
             endsAt: nil)
    }

    func showMicroReminder(color: MicroReminderColor) {
        show(content: AnyView(CursorMicroReminderView(color: color)),
             size: CursorMicroReminderView.panelSize,
             endsAt: .now.addingTimeInterval(6))
    }

    private func show(content: AnyView, size: CGSize, endsAt: Date?) {
        guard endsAt.map({ $0 > .now }) ?? true, !NSScreen.screens.isEmpty else {
            dismiss()
            return
        }
        autoDismissTask?.cancel()
        autoDismissTask = nil
        panelSize = size

        if let panel, let hostingView = panel.contentView as? NSHostingView<AnyView> {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) { hostingView.rootView = content }
            panel.setContentSize(size)
            hostingView.frame = NSRect(origin: .zero, size: size)
            movePanelToCursor()
        } else {
            let panel = NSPanel(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            let contentView = NSHostingView(rootView: content)
            contentView.frame = NSRect(origin: .zero, size: size)
            panel.contentView = contentView
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.animationBehavior = .none
            panel.ignoresMouseEvents = true
            panel.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) + 1)
            panel.hidesOnDeactivate = false
            panel.collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .transient]
            panel.isReleasedWhenClosed = false

            self.panel = panel
            movePanelToCursor()

            // Event-driven mouse monitoring: zero CPU wakeup when mouse is stationary.
            globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.movePanelToCursor() }
            }

            localMouseMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
            ) { [weak self] event in
                self?.movePanelToCursor()
                return event
            }
        }

        // Exact sleep until endsAt instead of polling every frame
        guard let endsAt else { return }
        let timeRemaining = max(0, endsAt.timeIntervalSinceNow)
        autoDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(timeRemaining))
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    func dismiss() {
        autoDismissTask?.cancel()
        autoDismissTask = nil

        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }

        panel?.orderOut(nil)
        panel = nil
    }

    private func movePanelToCursor() {
        guard let panel else { return }
        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) })
            ?? NSScreen.main else { return }

        let newOrigin = Self.origin(beside: pointer, size: panelSize, screenFrame: screen.frame)
        if panel.frame.origin != newOrigin {
            panel.setFrameOrigin(newOrigin)
        }
        if !panel.isVisible { panel.orderFrontRegardless() }
    }

    /// One shared left-side anchor for countdown, typing and automatic-pause badges.
    static func origin(beside pointer: NSPoint, size: CGSize, screenFrame: NSRect) -> NSPoint {
        NSPoint(
            x: min(max(pointer.x - size.width - 10, screenFrame.minX), screenFrame.maxX - size.width),
            y: min(max(pointer.y - size.height / 2 - 6, screenFrame.minY), screenFrame.maxY - size.height)
        )
    }
}

private struct CursorBreakCountdownView: View {
    static let panelSize = CGSize(width: 142, height: 42)

    let endsAt: Date
    let leadTime: TimeInterval

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { context in
            let remaining = max(0, endsAt.timeIntervalSince(context.date))
            let seconds = Int(remaining.rounded(.up))
            let progress = min(1, remaining / leadTime)

            HStack(spacing: 7) {
                Circle()
                    .stroke(.white.opacity(0.25), lineWidth: 2)
                    .overlay {
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 27, height: 27)

                Text(seconds.formatted())
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()

                Text("•")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.42))

                Text("menu.break")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .frame(width: Self.panelSize.width, height: Self.panelSize.height)
            .modifier(NotificationGlassBackground(cornerRadius: Self.panelSize.height / 2))
        }
    }
}

struct CursorMeetingPauseView: View {
    var repeats = false
    static let panelSize = CursorPauseBadgeStyle.panelSize
    private static let entranceDuration = 0.18
    private static let holdDuration = 1.5
    static let displayDuration = entranceDuration + holdDuration

    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 4) {
            Capsule().frame(width: 3, height: 14)
            Capsule().frame(width: 3, height: 14)
        }
        .modifier(CursorPauseBadgeStyle())
        .opacity(isVisible ? 1 : 0)
        .task {
            repeat {
                withAnimation(.easeOut(duration: Self.entranceDuration)) { isVisible = true }
                do {
                    try await Task.sleep(for: .seconds(Self.entranceDuration + Self.holdDuration))
                } catch { return }
                isVisible = false
                guard repeats else { return }
                do {
                    try await Task.sleep(for: .seconds(0.8))
                } catch { return }
            } while !Task.isCancelled
        }
    }
}

/// Shared by the live notification and the Automatic Pause preview.
struct CursorTypingPauseView: View {
    static let panelSize = CursorPauseBadgeStyle.panelSize

    var body: some View {
        Image(systemName: "keyboard")
            .font(.system(size: 18, weight: .regular))
            .modifier(CursorPauseBadgeStyle())
            .accessibilityLabel(Text("warning.typing"))
    }
}

/// One surface for both automatic-pause indicators in previews and live panels.
struct CursorPauseBadgeStyle: ViewModifier {
    static let panelSize = CGSize(width: 40, height: 40)

    func body(content: Content) -> some View {
        content
            .foregroundStyle(.white.opacity(0.92))
            .frame(width: 32, height: 32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(
                        colors: [.white.opacity(0.12), .white.opacity(0.02), .black.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(LinearGradient(
                        colors: [.white.opacity(0.34), .white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
            .frame(width: Self.panelSize.width, height: Self.panelSize.height)
            .environment(\.colorScheme, .dark)
    }
}
