import AppKit
import Darwin
import SwiftUI

@MainActor
final class CursorBreakCountdownPresenter {
    private var panel: NSPanel?
    private var trackingTimer: Timer?
    private var hideCount = 0

    func show(endsAt: Date) {
        dismiss()
        guard endsAt > .now, !NSScreen.screens.isEmpty else { return }

        let size = CursorBreakCountdownView.panelSize
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        let contentView = NSHostingView(rootView: CursorBreakCountdownView(endsAt: endsAt))
        contentView.frame = NSRect(origin: .zero, size: size)
        panel.contentView = contentView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) + 1)
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isReleasedWhenClosed = false

        self.panel = panel
        movePanelToCursor()
        panel.orderFrontRegardless()
        allowBackgroundCursorChanges()
        hideSystemCursorIfVisible()

        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if Date.now >= endsAt {
                    self.dismiss()
                } else {
                    self.movePanelToCursor()
                    self.hideSystemCursorIfVisible()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        trackingTimer = timer
    }

    func dismiss() {
        trackingTimer?.invalidate()
        trackingTimer = nil
        panel?.orderOut(nil)
        panel = nil

        for _ in 0..<hideCount {
            CGDisplayShowCursor(CGMainDisplayID())
        }
        hideCount = 0
    }

    private func movePanelToCursor() {
        guard let panel else { return }
        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) })
            ?? NSScreen.main else { return }

        let size = CursorBreakCountdownView.panelSize
        let x = pointer.x + size.width <= screen.frame.maxX
            ? pointer.x - 2
            : pointer.x - size.width + 2
        let y = pointer.y - size.height >= screen.frame.minY
            ? pointer.y - size.height + 2
            : pointer.y + 2
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        if !panel.isVisible { panel.orderFrontRegardless() }
    }

    private func hideSystemCursorIfVisible() {
        if let isVisible = Self.cursorIsVisible {
            if !isVisible() { return }
        } else if hideCount > 0 {
            return
        }
        if CGDisplayHideCursor(CGMainDisplayID()) == .success {
            hideCount += 1
        }
    }

    private static let cursorIsVisible: (() -> Bool)? = {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGCursorIsVisible") else {
            return nil
        }
        typealias VisibilityFunction = @convention(c) () -> boolean_t
        let function = unsafeBitCast(symbol, to: VisibilityFunction.self)
        return { function() != 0 }
    }()

    // A menu bar app is rarely foreground. This window-server property permits
    // cursor hiding while another app is active; failure leaves the overlay visible.
    private func allowBackgroundCursorChanges() {
        typealias MainConnectionFunction = @convention(c) () -> Int32
        typealias SetPropertyFunction = @convention(c) (Int32, Int32, CFString, CFTypeRef) -> Int32
        let handle = UnsafeMutableRawPointer(bitPattern: -2)
        guard let connectionSymbol = dlsym(handle, "CGSMainConnectionID"),
              let propertySymbol = dlsym(handle, "CGSSetConnectionProperty") else { return }
        let mainConnection = unsafeBitCast(connectionSymbol, to: MainConnectionFunction.self)
        let setProperty = unsafeBitCast(propertySymbol, to: SetPropertyFunction.self)
        let connection = mainConnection()
        _ = setProperty(connection, connection, "SetsCursorInBackground" as CFString, kCFBooleanTrue)
    }
}

private struct CursorBreakCountdownView: View {
    static let panelSize = CGSize(width: 142, height: 42)

    let endsAt: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, Int(endsAt.timeIntervalSince(context.date).rounded(.up)))
            let progress = min(1, Double(remaining) / SessionEngine.breakWarningLeadTime)

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

                Text(remaining.formatted())
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()

                Text("•")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.42))

                Text("Break")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .frame(width: Self.panelSize.width, height: Self.panelSize.height)
            .background(Color(red: 0.11, green: 0.11, blue: 0.11), in: Capsule())
        }
    }
}
