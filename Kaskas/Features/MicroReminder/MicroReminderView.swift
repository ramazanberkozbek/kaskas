import SwiftUI

struct MicroReminderView: View {
    let mascot: MicroReminderMascot
    let color: MicroReminderColor
    let commitmentMode: MicroReminderCommitmentMode
    let showsEscapeHint: Bool
    let onFinished: @MainActor () -> Void

    init(
        mascot: MicroReminderMascot,
        color: MicroReminderColor = .peach,
        commitmentMode: MicroReminderCommitmentMode = .flexible,
        showsEscapeHint: Bool = false,
        onFinished: @escaping @MainActor () -> Void = {}
    ) {
        self.mascot = mascot
        self.color = color
        self.commitmentMode = commitmentMode
        self.showsEscapeHint = showsEscapeHint
        self.onFinished = onFinished
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.78)
            VStack(spacing: 24) {
                MicroReminderMascotView(
                    mascot: mascot,
                    color: color,
                    size: 200,
                    animated: true,
                    onFinished: onFinished
                )
                if commitmentMode.allowsSkipping {
                    Button(action: onFinished) {
                        HStack(spacing: 8) {
                            Text("reminder.skip")
                            if showsEscapeHint {
                                Text(verbatim: "Esc").font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.65))
                            }
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(.white.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            if commitmentMode.allowsSkipping { onFinished() }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("reminder.title"))
    }
}

struct MicroReminderMascotView: View {
    let mascot: MicroReminderMascot
    let color: MicroReminderColor
    let size: CGFloat
    let animated: Bool
    var looping: Bool = false
    let onFinished: @MainActor () -> Void

    init(
        mascot: MicroReminderMascot,
        color: MicroReminderColor = .peach,
        size: CGFloat,
        animated: Bool,
        looping: Bool = false,
        onFinished: @escaping @MainActor () -> Void = {}
    ) {
        self.mascot = mascot
        self.color = color
        self.size = size
        self.animated = animated
        self.looping = looping
        self.onFinished = onFinished
    }

    var body: some View {
        FlameMascotView(
            mascot: mascot,
            color: color,
            size: size,
            animated: animated,
            looping: looping,
            onFinished: onFinished
        )
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
