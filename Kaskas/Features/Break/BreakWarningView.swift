import SwiftUI

struct BreakWarningView: View {
    let endsAt: Date
    let onStart: () -> Void
    let onPostpone: (TimeInterval) -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 16) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(Color(red: 1, green: 0.62, blue: 0.39))
                    .frame(width: 60, height: 60)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color(red: 1, green: 0.62, blue: 0.39).opacity(0.65))
                    }

                VStack(alignment: .leading, spacing: 4) {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let remaining = max(0, Int(endsAt.timeIntervalSince(context.date).rounded(.up)))
                        (Text("warning.title") + Text(" ") + Text(String(format: "%02d:%02d", remaining / 60, remaining % 60)))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }

                    Text("warning.subtitle")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                }
            }

            HStack(spacing: 10) {
                action("warning.startNow", prominent: true, action: onStart)
                action("warning.oneMinute") { onPostpone(60) }
                action("warning.fiveMinutes") { onPostpone(5 * 60) }
                action("warning.skip", action: onSkip)
            }
        }
        .padding(22)
        .frame(width: 600, height: 164)
        .background(Color(red: 0.15, green: 0.15, blue: 0.15), in: RoundedRectangle(cornerRadius: 28))
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.white.opacity(0.08))
        }
        .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
    }

    private func action(
        _ title: LocalizedStringKey,
        prominent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .frame(height: 42)
                .background(
                    prominent ? Color.white.opacity(0.18) : Color.clear,
                    in: Capsule()
                )
                .overlay {
                    Capsule().stroke(Color.white.opacity(prominent ? 0 : 0.22))
                }
        }
        .buttonStyle(.plain)
    }
}
