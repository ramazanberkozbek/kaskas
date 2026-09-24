import AppKit
import Combine
import SwiftUI

struct MenuBarView: View {
    let controller: SessionController

    @State private var now = Date.now

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
                .padding(.top, Theme.Spacing.medium)

            ProgressView(value: snapshot.progress)
                .progressViewStyle(.linear)
                .tint(.accentColor)
                .padding(.top, Theme.Spacing.medium)

            Divider()
                .padding(.vertical, Theme.Spacing.large)

            actions(for: snapshot)

            Divider()
                .padding(.vertical, Theme.Spacing.large)

            footer
        }
        .padding(Theme.Spacing.large)
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
        HStack(spacing: Theme.Spacing.medium) {
            Text(snapshot.phase == .focusing ? "menu.nextBreak" : "menu.break")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Spacer()

            HStack(spacing: Theme.Spacing.small) {
                Circle()
                    .fill(.green)
                    .frame(width: 7, height: 7)

                Text("menu.active")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.green)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.green.opacity(0.14), in: RoundedRectangle(cornerRadius: 7))
        }
    }

    private func countdown(for snapshot: SessionSnapshot) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.medium) {
            Text(
                timerInterval: snapshot.startedAt...snapshot.endsAt,
                pauseTime: nil,
                countsDown: true,
                showsHours: false
            )
            .font(.system(size: 42, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .contentTransition(.numericText())
            .accessibilityLabel("menu.remaining")

            (Text("menu.atTime") + Text(" ") + Text(snapshot.endsAt, style: .time))
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func actions(for snapshot: SessionSnapshot) -> some View {
        if snapshot.phase == .focusing {
            HStack(spacing: Theme.Spacing.medium) {
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
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 34)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            SettingsLink {
                Text("menu.settings")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("menu.quit")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .font(.body.weight(.medium))
    }
}
