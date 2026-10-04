import AppKit
import Combine
import SwiftUI

struct MenuBarView: View {
    let controller: SessionController

    @Environment(\.dismiss) private var dismiss
    @State private var now = Date.now
    @State private var isBadgeHovered = false
    @State private var hoveredAction: ActionItem?
    @State private var hoveredFooterItem: FooterItem?

    private enum ActionItem {
        case startBreak
        case snooze
        case completeBreak
    }

    private enum FooterItem {
        case settings
        case quit
    }

    private enum BadgeStatus {
        case shortBreak
        case longBreak
        case manualPause
        case meetingPause
        case idlePause
        case onBreak

        init(snapshot: SessionSnapshot) {
            switch snapshot.status {
            case .suspended(let suspension):
                switch suspension.reason {
                case .manual, .system:
                    self = .manualPause
                case .idle:
                    self = .idlePause
                case .meeting:
                    self = .meetingPause
                }
            case .onBreak:
                self = .onBreak
            case .focusing:
                self = snapshot.nextBreakKind == .long ? .longBreak : .shortBreak
            }
        }

        var title: LocalizedStringKey {
            switch self {
            case .shortBreak: "menu.badge.shortBreak"
            case .longBreak: "menu.badge.longBreak"
            case .manualPause: "menu.badge.manualPause"
            case .meetingPause: "menu.badge.meetingPause"
            case .idlePause: "menu.badge.idlePause"
            case .onBreak: "menu.badge.onBreak"
            }
        }

        var color: Color {
            switch self {
            case .shortBreak: Color(red: 0.40, green: 0.61, blue: 0.96)
            case .longBreak: Color(red: 0.98, green: 0.68, blue: 0.35)
            case .manualPause: Color(red: 0.72, green: 0.72, blue: 0.76)
            case .meetingPause: Color(red: 0.69, green: 0.56, blue: 0.94)
            case .idlePause: Color(red: 0.98, green: 0.68, blue: 0.35)
            case .onBreak: Color(red: 0.43, green: 0.77, blue: 0.48)
            }
        }
    }

    private let clock = Timer.publish(
        every: 1,
        on: .main,
        in: .common
    ).autoconnect()

    var body: some View {
        let snapshot = controller.snapshot(at: now)

        VStack(alignment: .leading, spacing: 0) {
            header(for: snapshot)

            countdown(for: snapshot)
                .padding(.top, 8)

            ProgressView(value: snapshot.progress)
                .progressViewStyle(.linear)
                .tint(Color(red: 0.35, green: 0.72, blue: 0.29))
                .padding(.top, 7)

            Divider()
                .padding(.top, 18)
                .padding(.bottom, 11)

            if !snapshot.status.isManualPaused {
                actions(for: snapshot)

                Divider()
                    .padding(.top, 11)
            }

            todayRow

            if controller.historySaveFailed {
                Label("menu.historySaveFailed", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.vertical, 6)
            }

            Divider()

            footer
                .padding(.top, 8)
        }
        .padding(16)
        .frame(width: Theme.Size.menuWidth)
        .onAppear {
            let currentDate = Date.now
            now = currentDate
            if !controller.sessionSnapshot.status.isPaused,
               currentDate >= controller.sessionSnapshot.endsAt {
                controller.reconcile(at: currentDate)
            }
        }
        .onReceive(clock) { currentDate in
            now = currentDate

            // The scheduler owns background transitions. This foreground check
            // also keeps the popover correct after sleep or a large clock jump.
            if !controller.sessionSnapshot.status.isPaused,
               currentDate >= controller.sessionSnapshot.endsAt {
                controller.reconcile(at: currentDate)
            }
        }
    }

    private func header(for snapshot: SessionSnapshot) -> some View {
        HStack {
            Text(snapshot.phase == .focusing ? "menu.nextBreak" : "menu.break")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1)

            Spacer()

            let status = BadgeStatus(snapshot: snapshot)
            Button(action: controller.toggleManualPause) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(status.color)
                        .frame(width: 5, height: 5)
                        .accessibilityHidden(true)

                    Text(status.title)
                        .font(.system(size: 11, weight: .bold))
                        .lineLimit(1)
                }
                .foregroundStyle(status.color)
                .padding(.horizontal, 8)
                .frame(height: 22)
                .background(
                    status.color.opacity(isBadgeHovered ? 0.32 : 0.17),
                    in: RoundedRectangle(cornerRadius: 6)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(status.color.opacity(isBadgeHovered ? 0.55 : 0), lineWidth: 1)
                        .allowsHitTesting(false)
                }
                .contentShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .onHover { isBadgeHovered = $0 }
            .animation(.easeOut(duration: 0.15), value: isBadgeHovered)
            .accessibilityLabel(snapshot.status.isManualPaused ? "menu.resume" : "menu.pause")
        }
    }

    private func countdown(for snapshot: SessionSnapshot) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            if snapshot.status.isPaused {
                Text(Self.pausedCountdownString(for: snapshot.remaining))
                    .font(.system(size: 30, weight: .bold))
                    .monospacedDigit()
                    .accessibilityLabel("menu.remaining")
            } else {
                Text(
                    timerInterval: snapshot.startedAt...snapshot.endsAt,
                    countsDown: true,
                    showsHours: false
                )
                .font(.system(size: 30, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .accessibilityLabel("menu.remaining")
            }

            if !snapshot.status.isPaused {
                (Text("menu.atTime") + Text(" ") + Text(snapshot.endsAt, style: .time))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }

    private static func pausedCountdownString(for remaining: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: ceil(max(0, remaining))) ?? "0:00"
    }

    private func actions(for snapshot: SessionSnapshot) -> some View {
        HStack(spacing: 6) {
            if snapshot.phase == .focusing {
                actionButton(
                    "menu.startBreak",
                    item: .startBreak,
                    systemImage: "play.circle",
                    action: controller.startBreakNow
                )

                if !snapshot.status.isMeetingPaused {
                    actionButton(
                        "menu.snooze",
                        item: .snooze,
                        systemImage: "alarm",
                        action: controller.snooze
                    )
                }
            } else {
                actionButton(
                    "menu.completeBreak",
                    item: .completeBreak,
                    systemImage: "checkmark.circle",
                    action: controller.completeBreak
                )
            }
        }
    }

    private func actionButton(
        _ titleKey: LocalizedStringKey,
        item: ActionItem,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(titleKey, systemImage: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 34)
                .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .background(
            .white.opacity(hoveredAction == item ? 0.17 : 0.07),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.white.opacity(hoveredAction == item ? 0.25 : 0), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .onHover { isHovering in
            if isHovering {
                hoveredAction = item
            } else if hoveredAction == item {
                hoveredAction = nil
            }
        }
        .animation(.easeOut(duration: 0.15), value: hoveredAction)
    }

    private var todayRow: some View {
        HStack {
            Text("menu.today")
                .foregroundStyle(.secondary)

            Spacer()

            Text(MenuBarDurationFormatter.screenTimeString(for: controller.screenTimeToday(at: now), locale: controller.locale))
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Text("menu.screenTime")
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 11, weight: .semibold))
        .frame(height: 42)
        .padding(.horizontal, 2)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 0) {
            footerButton("menu.settings", item: .settings) {
                let menuWindow = NSApp.keyWindow
                dismiss()
                menuWindow?.orderOut(nil)
                controller.openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)

            footerButton("menu.quit", item: .quit) {
                NSApplication.shared.terminate(nil)
            }
        }
        .font(.system(size: 12, weight: .medium))
        .padding(.horizontal, -11)
    }

    private func footerButton(
        _ titleKey: LocalizedStringKey,
        item: FooterItem,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(titleKey)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 24)
                .padding(.horizontal, 11)
                .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .foregroundStyle(hoveredFooterItem == item ? .white : .primary)
        .background(
            hoveredFooterItem == item
                ? Color(red: 0.21, green: 0.53, blue: 0.12)
                : .clear,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .onHover { isHovering in
            if isHovering {
                hoveredFooterItem = item
            } else if hoveredFooterItem == item {
                hoveredFooterItem = nil
            }
        }
    }
}
