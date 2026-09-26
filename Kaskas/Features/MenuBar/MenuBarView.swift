import AppKit
import Combine
import SwiftUI

struct MenuBarView: View {
    let controller: SessionController

    @State private var now = Date.now
    @State private var hoveredFooterItem: FooterItem?

    private enum FooterItem {
        case settings
        case quit
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

            actions(for: snapshot)

            Divider()
                .padding(.top, 11)

            todayRow

            Divider()

            footer
                .padding(.top, 8)
        }
        .padding(16)
        .frame(width: Theme.Size.menuWidth)
        .onAppear {
            let currentDate = Date.now
            now = currentDate
            controller.reconcile(at: currentDate)
        }
        .onReceive(clock) { currentDate in
            now = currentDate

            // The scheduler owns background transitions. This foreground check
            // also keeps the popover correct after sleep or a large clock jump.
            if currentDate >= controller.sessionSnapshot.endsAt {
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
        }
    }

    private func countdown(for snapshot: SessionSnapshot) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Group {
                if controller.isPaused {
                    Text(Duration.seconds(snapshot.remaining).formatted(.time(pattern: .hourMinuteSecond)))
                } else {
                    Text(
                        timerInterval: snapshot.startedAt...snapshot.endsAt,
                        pauseTime: nil,
                        countsDown: true,
                        showsHours: false
                    )
                }
            }
            .font(.system(size: 30, weight: .bold))
            .monospacedDigit()
            .contentTransition(.numericText())
            .accessibilityLabel("menu.remaining")

            (Text("menu.atTime") + Text(" ") + Text(snapshot.endsAt, style: .time))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func actions(for snapshot: SessionSnapshot) -> some View {
        if snapshot.phase == .focusing {
            HStack(spacing: 6) {
                actionButton(
                    "menu.startBreak",
                    systemImage: "play.circle",
                    action: controller.startBreakNow
                )

                actionButton(
                    "menu.snooze",
                    systemImage: "alarm",
                    action: controller.snooze
                )
            }
        } else {
            actionButton(
                "menu.completeBreak",
                systemImage: "checkmark.circle",
                action: controller.completeBreak
            )
        }
    }

    private func actionButton(
        _ titleKey: LocalizedStringKey,
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
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }

    private var todayRow: some View {
        HStack {
            Text("menu.today")
                .foregroundStyle(.secondary)

            Spacer()

            Text(controller.breaksTakenToday(at: now).formatted())
                .foregroundStyle(.primary)

            Text("menu.breaksTaken")
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 11, weight: .semibold))
        .frame(height: 42)
        .padding(.horizontal, 2)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 0) {
            footerButton("menu.settings", item: .settings) {
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
