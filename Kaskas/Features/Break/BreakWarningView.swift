import SwiftUI

struct BreakWarningView: View {
    static let panelSize = CGSize(width: 460, height: 126)

    private let accent = Color(red: 1, green: 0.62, blue: 0.39)

    let endsAt: Date
    let leadTime: TimeInterval
    let onStart: () -> Void
    let onPostpone: (TimeInterval) -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            countdownHeader

            HStack(spacing: 7) {
                WarningActionButton(
                    title: "warning.startNow",
                    prominent: true,
                    action: onStart
                )
                WarningActionButton(title: "warning.oneMinute") {
                    onPostpone(60)
                }
                WarningActionButton(title: "warning.fiveMinutes") {
                    onPostpone(5 * 60)
                }
                WarningActionButton(title: "warning.fifteenMinutes") {
                    onPostpone(15 * 60)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(width: Self.panelSize.width - 32, alignment: .leading)
        .padding(16)
        .frame(width: Self.panelSize.width, height: Self.panelSize.height)
        .modifier(NotificationGlassBackground(cornerRadius: 20))
        .overlay {
            CountdownBorder(
                endsAt: endsAt,
                duration: leadTime,
                cornerRadius: 20,
                color: accent
            )
        }
    }

    private var countdownHeader: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, endsAt.timeIntervalSince(context.date))
            let seconds = Int(remaining.rounded(.up))

            HStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(accent)
                    .frame(width: 48, height: 48)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1.5)
                    }
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "%02d:%02d", seconds / 60, seconds % 60))
                        .font(NotificationTypography.title())
                        .monospacedDigit()
                        .foregroundStyle(.white)

                    Text("warning.subtitle")
                        .font(NotificationTypography.message())
                        .foregroundStyle(.white.opacity(0.65))
                }

                Spacer(minLength: 0)

                WarningCloseButton(action: onSkip)
            }
        }
    }
}

private struct WarningCloseButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(isHovered ? 0.85 : 0.35))
                .frame(width: 24, height: 24)
                .background(
                    Color.white.opacity(isHovered ? 0.12 : 0.04),
                    in: Circle()
                )
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(isHovered ? 0.25 : 0.10), lineWidth: 0.5)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .help(Text("warning.skip"))
    }
}

private struct WarningActionButton: View {
    let title: LocalizedStringKey
    var prominent: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(NotificationTypography.action())
                .foregroundStyle(.white.opacity(prominent ? 1.0 : (isHovered ? 0.95 : 0.85)))
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(
                    backgroundColor,
                    in: Capsule()
                )
                .overlay {
                    Capsule()
                        .stroke(borderColor, lineWidth: 1)
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }

    private var backgroundColor: Color {
        if prominent {
            return Color.white.opacity(isHovered ? 0.18 : 0.11)
        } else {
            return Color.white.opacity(isHovered ? 0.08 : 0.03)
        }
    }

    private var borderColor: Color {
        if prominent {
            return Color.white.opacity(isHovered ? 0.38 : 0.22)
        } else {
            return Color.white.opacity(isHovered ? 0.28 : 0.16)
        }
    }
}
