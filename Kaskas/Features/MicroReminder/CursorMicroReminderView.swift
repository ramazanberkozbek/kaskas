import SwiftUI

/// A small cursor badge with no breathing, entrance or exit motion.
struct CursorMicroReminderView: View {
    static let panelSize = CursorPauseBadgeStyle.panelSize
    var color: MicroReminderColor = .white
    var animated = true

    var body: some View {
        FlameMascotView(mascot: .flame, color: color, size: 24,
                        animated: animated, looping: true, blinkingOnly: true)
            .modifier(CursorPauseBadgeStyle())
            .accessibilityLabel(Text("reminder.title"))
    }
}
