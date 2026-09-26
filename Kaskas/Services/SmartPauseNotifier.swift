import AppKit
import SwiftUI

@MainActor
final class SmartPauseNotifier {
    private static let displayDuration: TimeInterval = 4
    private var panel: NSPanel?
    private var dismissalTask: Task<Void, Never>?

    func notify(trigger: SmartPauseTrigger) {
        dismiss()
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
            ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let size = SmartPauseNotificationView.panelSize
        let frame = NSRect(
            x: screen.visibleFrame.midX - size.width / 2,
            y: screen.visibleFrame.maxY - size.height - 22,
            width: size.width,
            height: size.height
        )
        let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        let expiresAt = Date.now.addingTimeInterval(Self.displayDuration)
        panel.contentView = NSHostingView(rootView: SmartPauseNotificationView(
            trigger: trigger,
            expiresAt: expiresAt,
            displayDuration: Self.displayDuration
        ))
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .transient]
        panel.orderFrontRegardless()
        self.panel = panel
        dismissalTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(Self.displayDuration))
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    func dismiss() {
        dismissalTask?.cancel()
        dismissalTask = nil
        panel?.orderOut(nil)
        panel = nil
    }
}

private struct SmartPauseNotificationView: View {
    static let panelSize = CGSize(width: 375, height: 96)

    let trigger: SmartPauseTrigger
    let expiresAt: Date
    let displayDuration: TimeInterval

    private var icon: String {
        switch trigger {
        case .calls: "phone.fill"
        case .video: "play.rectangle.fill"
        case .focusApp: "square.grid.2x2.fill"
        }
    }

    private var heading: LocalizedStringKey {
        switch trigger {
        case .calls: "smartPause.notification.calls"
        case .video: "smartPause.notification.video"
        case .focusApp: "smartPause.notification.focusApp"
        }
    }

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 23, weight: .medium))
                .foregroundStyle(Color(red: 0.74, green: 0.62, blue: 1))
                .frame(width: 54, height: 54)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 17))
                .overlay { RoundedRectangle(cornerRadius: 17).stroke(.white.opacity(0.16)) }

            VStack(alignment: .leading, spacing: 3) {
                Text(heading)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(Color(red: 0.82, green: 0.74, blue: 1))
                Text("smartPause.notification.title")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("smartPause.notification.body")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.68))
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(width: Self.panelSize.width, height: Self.panelSize.height)
        .background(Color(red: 0.18, green: 0.16, blue: 0.21), in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            CountdownBorder(
                endsAt: expiresAt,
                duration: displayDuration,
                cornerRadius: 24,
                color: Color(red: 0.74, green: 0.62, blue: 1)
            )
        }
        .shadow(color: .black.opacity(0.38), radius: 16, y: 7)
    }
}
