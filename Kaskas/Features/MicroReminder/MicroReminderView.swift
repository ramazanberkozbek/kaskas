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

private struct FlameMascotView: View {
    let color: MicroReminderColor
    let size: CGFloat
    let animated: Bool
    let onFinished: @MainActor () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appearanceScale: CGFloat = 0.18
    @State private var appearanceOpacity = 0.0
    @State private var isBlinking = false
    @State private var isSmiling = false
    @State private var leftTipMotion: CGFloat = 0
    @State private var centerTipMotion: CGFloat = 0
    @State private var rightTipMotion: CGFloat = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            flameShape
                .stroke(color.glowColor.opacity(0.40), lineWidth: size * 0.15)
                .blur(radius: size * 0.20)
                .blendMode(.screen)

            flameShape
                .stroke(color.glowColor.opacity(0.34), lineWidth: size * 0.06)
                .blur(radius: size * 0.07)
                .blendMode(.plusLighter)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: color.gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .mask { flameShape.fill(.white) }
        }
        .frame(width: size, height: size * 1.1)
        .padding(glowPadding)
        .mask {
            Rectangle()
                .fill(.white)
                .overlay {
                    ZStack(alignment: .topLeading) {
                        eye.position(x: glowPadding + size * 0.35, y: glowPadding + size * 0.725)
                            .opacity(isSmiling || !animated ? 0 : 1)
                            .blendMode(.destinationOut)
                        eye.position(x: glowPadding + size * 0.65, y: glowPadding + size * 0.725)
                            .opacity(isSmiling || !animated ? 0 : 1)
                            .blendMode(.destinationOut)
                        smilingEye.position(x: glowPadding + size * 0.35, y: glowPadding + size * 0.74)
                            .opacity(isSmiling || !animated ? 1 : 0)
                            .blendMode(.destinationOut)
                        smilingEye.position(x: glowPadding + size * 0.65, y: glowPadding + size * 0.74)
                            .opacity(isSmiling || !animated ? 1 : 0)
                            .blendMode(.destinationOut)
                    }
                }
                .compositingGroup()
        }
        .frame(width: size, height: size * 1.1)
        .scaleEffect(animated ? appearanceScale : 1)
        .opacity(animated ? appearanceOpacity : 1)
        .task {
            guard animated else { return }

            if reduceMotion {
                appearanceScale = 1
                withAnimation(.easeOut(duration: 0.2)) { appearanceOpacity = 1 }
                do {
                    try await Task.sleep(for: .seconds(4.1))
                } catch {
                    return
                }
                withAnimation(.easeIn(duration: 0.3)) { appearanceOpacity = 0 }
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                onFinished()
                return
            }

            withAnimation(.spring(response: 0.65, dampingFraction: 0.75)) {
                appearanceScale = 1
                appearanceOpacity = 1
            }

            do {
                try await Task.sleep(for: .milliseconds(500))
                for _ in 0..<5 {
                    withAnimation(.easeIn(duration: 0.12)) { isBlinking = true }
                    try await Task.sleep(for: .milliseconds(230))
                    withAnimation(.easeOut(duration: 0.15)) { isBlinking = false }
                    try await Task.sleep(for: .milliseconds(350))
                }
                withAnimation(.easeInOut(duration: 0.5)) { isSmiling = true }
                // Include the transition so the completed smile stays visible for a full second.
                try await Task.sleep(for: .milliseconds(1500))
                withAnimation(.easeInOut(duration: 0.38)) {
                    appearanceScale = 0.12
                    appearanceOpacity = 0
                }
                try await Task.sleep(for: .milliseconds(380))
                onFinished()
            } catch {
                return
            }
        }
        .task {
            guard animated, !reduceMotion else { return }
            await animateFlame()
        }
    }

    private var eye: some View {
        Capsule()
            .fill(.black)
            .frame(width: size * 0.075, height: size * 0.095)
            .scaleEffect(y: isBlinking ? 0.09 : 1)
    }

    private var glowPadding: CGFloat { size * 0.35 }

    private var smilingEye: some View {
        SmilingEye()
            .stroke(.black, style: StrokeStyle(lineWidth: size * 0.03, lineCap: .round))
            .frame(width: size * 0.16, height: size * 0.08)
    }

    private var flameShape: FlameBody {
        FlameBody(
            leftTipMotion: leftTipMotion,
            centerTipMotion: centerTipMotion,
            rightTipMotion: rightTipMotion
        )
    }

    @MainActor
    private func animateFlame() async {
        while !Task.isCancelled {
            let duration = Double.random(in: 0.5...0.95)
            withAnimation(.easeInOut(duration: duration)) {
                switch Int.random(in: 0...2) {
                case 0: leftTipMotion = CGFloat.random(in: -1...1)
                case 1: centerTipMotion = CGFloat.random(in: -1...1)
                default: rightTipMotion = CGFloat.random(in: -1...1)
                }
            }
            do {
                try await Task.sleep(for: .milliseconds(Int.random(in: 260...480)))
            } catch {
                return
            }
        }
    }
}

private struct FlameBody: Shape {
    var leftTipMotion: CGFloat
    var centerTipMotion: CGFloat
    var rightTipMotion: CGFloat

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { .init(leftTipMotion, .init(centerTipMotion, rightTipMotion)) }
        set {
            leftTipMotion = newValue.first
            centerTipMotion = newValue.second.first
            rightTipMotion = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let centerTip = CGPoint(x: 100 + centerTipMotion * 6, y: 12 - centerTipMotion * 7)
        path.move(to: centerTip)
        path.addCurve(to: CGPoint(x: 79, y: 65), control1: CGPoint(x: 99 + centerTipMotion * 3, y: 37), control2: CGPoint(x: 87, y: 51))
        path.addCurve(to: CGPoint(x: 76 - centerTipMotion * 3, y: 14 + centerTipMotion * 3),
                      control1: CGPoint(x: 70, y: 49), control2: CGPoint(x: 72, y: 31))
        path.addCurve(to: CGPoint(x: 40, y: 90), control1: CGPoint(x: 48, y: 37), control2: CGPoint(x: 35, y: 62))
        path.addCurve(to: CGPoint(x: 27 + leftTipMotion * 5, y: 45 - leftTipMotion * 5),
                      control1: CGPoint(x: 27, y: 79), control2: CGPoint(x: 21, y: 61))
        path.addCurve(to: CGPoint(x: 22, y: 114), control1: CGPoint(x: 8, y: 70), control2: CGPoint(x: 7, y: 94))
        path.addCurve(to: CGPoint(x: 18, y: 172), control1: CGPoint(x: 15, y: 132), control2: CGPoint(x: 13, y: 150))
        path.addCurve(to: CGPoint(x: 100, y: 215), control1: CGPoint(x: 25, y: 201), control2: CGPoint(x: 54, y: 215))
        path.addCurve(to: CGPoint(x: 182, y: 170), control1: CGPoint(x: 145, y: 215), control2: CGPoint(x: 174, y: 200))
        path.addCurve(to: CGPoint(x: 157, y: 88), control1: CGPoint(x: 191, y: 136), control2: CGPoint(x: 176, y: 112))
        path.addCurve(to: CGPoint(x: 171 + rightTipMotion * 6, y: 35 - rightTipMotion * 6),
                      control1: CGPoint(x: 153, y: 70), control2: CGPoint(x: 158, y: 51))
        path.addCurve(to: CGPoint(x: 124, y: 76), control1: CGPoint(x: 148, y: 41), control2: CGPoint(x: 134, y: 57))
        path.addCurve(to: centerTip, control1: CGPoint(x: 129, y: 51), control2: CGPoint(x: 121, y: 29))
        path.closeSubpath()

        return path.applying(CGAffineTransform(
            a: rect.width / 200, b: 0,
            c: 0, d: rect.height / 220,
            tx: rect.minX, ty: rect.minY
        ))
    }
}

private struct SmilingEye: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY * 0.8))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY * 0.8),
            control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.25)
        )
        return path
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
