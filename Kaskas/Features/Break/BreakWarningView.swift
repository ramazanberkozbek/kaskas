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
                action("warning.skip", action: onSkip)
                action("warning.oneMinute") { onPostpone(60) }
                action("warning.fiveMinutes") { onPostpone(5 * 60) }
                Spacer(minLength: 0)
                action("warning.startNow", prominent: true, action: onStart)
            }
        }
        .frame(width: Self.panelSize.width - 32, alignment: .leading)
        .padding(16)
        .frame(width: Self.panelSize.width, height: Self.panelSize.height)
        .background(Color(red: 0.15, green: 0.15, blue: 0.15), in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            CountdownBorder(
                endsAt: endsAt,
                duration: leadTime,
                cornerRadius: 20,
                color: accent
            )
        }
        .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
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
                    (Text("warning.title") + Text(" ") + Text(String(format: "%02d:%02d", seconds / 60, seconds % 60)))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)

                    Text("warning.subtitle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
        }
    }

    private func action(
        _ title: LocalizedStringKey,
        prominent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(
                    prominent ? Color.white.opacity(0.18) : Color.clear,
                    in: Capsule()
                )
                .overlay {
                    Capsule().stroke(Color.white.opacity(prominent ? 0 : 0.22))
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
