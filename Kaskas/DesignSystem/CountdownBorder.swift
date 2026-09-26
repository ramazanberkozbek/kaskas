import SwiftUI

/// A border that drains until the hosting notification's dismissal deadline.
struct CountdownBorder: View {
    let endsAt: Date
    let duration: TimeInterval
    let cornerRadius: CGFloat
    let color: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
            let remaining = min(1, max(0, endsAt.timeIntervalSince(context.date) / duration))
            RoundedRectangle(cornerRadius: cornerRadius - 1)
                .stroke(.white.opacity(0.14), lineWidth: 1.5)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius - 1)
                        .trim(from: 0, to: remaining)
                        .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                }
                .padding(1.5)
        }
        .allowsHitTesting(false)
    }
}
