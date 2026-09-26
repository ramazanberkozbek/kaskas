import SwiftUI

struct MicroReminderView: View {
    let mascot: MicroReminderMascot
    let color: MicroReminderColor
    let onFinished: @MainActor () -> Void

    init(
        mascot: MicroReminderMascot,
        color: MicroReminderColor = .peach,
        onFinished: @escaping @MainActor () -> Void = {}
    ) {
        self.mascot = mascot
        self.color = color
        self.onFinished = onFinished
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.78)
            MicroReminderMascotView(
                mascot: mascot,
                color: color,
                size: 200,
                animated: true,
                onFinished: onFinished
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("reminder.title"))
    }
}

struct MicroReminderMascotView: View {
    let mascot: MicroReminderMascot
    let color: MicroReminderColor
    let size: CGFloat
    let animated: Bool
    let onFinished: @MainActor () -> Void

    init(
        mascot: MicroReminderMascot,
        color: MicroReminderColor = .peach,
        size: CGFloat,
        animated: Bool,
        onFinished: @escaping @MainActor () -> Void = {}
    ) {
        self.mascot = mascot
        self.color = color
        self.size = size
        self.animated = animated
        self.onFinished = onFinished
    }

    var body: some View {
        switch mascot {
        case .flame:
            FlameMascotView(
                color: color,
                size: size,
                animated: animated,
                onFinished: onFinished
            )
        }
    }
}

extension MicroReminderColor {
    var gradientColors: [Color] {
        switch self {
        case .white: [.white, Color(red: 0.88, green: 0.91, blue: 0.98)]
        case .blue: [Color(red: 0.86, green: 0.93, blue: 1), Color(red: 0.49, green: 0.69, blue: 1)]
        case .mint: [Color(red: 0.85, green: 1, blue: 0.93), Color(red: 0.45, green: 0.85, blue: 0.72)]
        case .lavender: [Color(red: 0.95, green: 0.90, blue: 1), Color(red: 0.70, green: 0.59, blue: 0.96)]
        case .peach: [Color(red: 1, green: 0.91, blue: 0.79), Color(red: 1, green: 0.71, blue: 0.51)]
        case .pink: [Color(red: 1, green: 0.88, blue: 0.94), Color(red: 1, green: 0.61, blue: 0.75)]
        case .yellow: [Color(red: 1, green: 0.97, blue: 0.79), Color(red: 1, green: 0.81, blue: 0.41)]
        case .rainbow: [.pink, .orange, .yellow, .green, .cyan, .purple]
        }
    }

    var glowColor: Color {
        switch self {
        case .white: .white
        case .blue: .blue
        case .mint: .mint
        case .lavender: .purple
        case .peach: .orange
        case .pink: .pink
        case .yellow: .yellow
        case .rainbow: .orange
        }
    }
}
