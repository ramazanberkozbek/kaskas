import SwiftUI

struct BreakView: View {
    let endsAt: Date
    let onComplete: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: Theme.Spacing.extraLarge) {
                Image("Mascot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .accessibilityHidden(true)

                VStack(spacing: Theme.Spacing.medium) {
                    Text("break.title")
                        .font(Theme.Typography.breakTitle)

                    Text("break.message")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                let formattedRemaining = Self.formattedRemaining(
                    until: endsAt,
                    now: context.date
                )

                Text(formattedRemaining)
                    .font(Theme.Typography.countdown)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .accessibilityLabel("break.remaining.label")
                    .accessibilityValue(formattedRemaining)

                Button("break.complete", action: onComplete)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .padding(Theme.Spacing.extraLarge)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                ZStack {
                    Color(nsColor: .windowBackgroundColor)
                    RadialGradient(
                        colors: [Color.accentColor.opacity(0.14), .clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: 520
                    )
                }
                .ignoresSafeArea()
            }
        }
    }

    private static func formattedRemaining(until endDate: Date, now: Date) -> String {
        let totalSeconds = max(0, Int(endDate.timeIntervalSince(now).rounded(.up)))
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}
