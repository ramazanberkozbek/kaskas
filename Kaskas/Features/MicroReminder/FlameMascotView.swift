import SwiftUI

struct FlameMascotView: View {
    let color: MicroReminderColor
    let size: CGFloat
    let animated: Bool
    let onFinished: @MainActor () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt: Date?
    @State private var didFinish = false

    var body: some View {
        Group {
            if animated {
                TimelineView(.animation(minimumInterval: reduceMotion ? 0.25 : 1.0 / 60.0)) { context in
                    let elapsed = context.date.timeIntervalSince(startedAt ?? context.date)
                    let pose = FlameAnimationTimeline.pose(at: elapsed, reduceMotion: reduceMotion)

                    artwork(pose: pose)
                        .onChange(of: pose.finished) { _, finished in
                            guard finished, !didFinish else { return }
                            didFinish = true
                            onFinished()
                        }
                }
            } else {
                artwork(pose: .init(
                    eyeOpenness: 1,
                    smileProgress: 1,
                    breathingScale: 1,
                    appearanceScale: 1,
                    opacity: 1,
                    finished: false
                ))
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            guard animated else { return }
            didFinish = false
            startedAt = Date()
        }
    }

    private func artwork(pose: FlameAnimationTimeline.Pose) -> some View {
        ZStack {
            FlameSilhouette()
                .stroke(color.glowColor.opacity(0.10), lineWidth: size * 0.045)
                .scaleEffect(1.035)

            FlameSilhouette()
                .stroke(color.glowColor.opacity(0.18), lineWidth: size * 0.015)
                .scaleEffect(1.015)

            FlameCutOut(
                eyeOpenness: CGFloat(pose.eyeOpenness),
                smileProgress: CGFloat(pose.smileProgress)
            )
            .fill(
                LinearGradient(
                    colors: color.gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                style: FillStyle(eoFill: true)
            )
        }
        .frame(width: size, height: size)
        .scaleEffect(y: CGFloat(pose.breathingScale), anchor: .bottom)
        .scaleEffect(CGFloat(pose.appearanceScale))
        .opacity(pose.opacity)
    }
}

private struct FlameSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        FlameGeometry.body.applying(FlameGeometry.transform(for: rect))
    }
}

private struct FlameCutOut: Shape {
    let eyeOpenness: CGFloat
    let smileProgress: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = FlameGeometry.body
        path.addPath(FlameGeometry.eye(centerX: 41, openness: eyeOpenness, smile: smileProgress))
        path.addPath(FlameGeometry.eye(centerX: 79, openness: eyeOpenness, smile: smileProgress))
        return path.applying(FlameGeometry.transform(for: rect))
    }
}

private enum FlameGeometry {
    // Keep this 120 × 120 contour aligned with Artwork/Mascot/Drafts/FlameFace.svg.
    nonisolated static var body: Path {
        var path = Path()
        path.move(to: CGPoint(x: 60, y: 114))
        path.addCurve(to: CGPoint(x: 18.6, y: 82), control1: CGPoint(x: 35.2, y: 114), control2: CGPoint(x: 19.2, y: 101.5))
        path.addCurve(to: CGPoint(x: 35.6, y: 44.5), control1: CGPoint(x: 18.1, y: 68.2), control2: CGPoint(x: 24, y: 57.4))
        path.addCurve(to: CGPoint(x: 46.7, y: 5.5), control1: CGPoint(x: 44.9, y: 34.1), control2: CGPoint(x: 49.1, y: 22.6))
        path.addCurve(to: CGPoint(x: 68.4, y: 42.6), control1: CGPoint(x: 62.8, y: 14.7), control2: CGPoint(x: 69.8, y: 27.6))
        path.addCurve(to: CGPoint(x: 90.5, y: 22.3), control1: CGPoint(x: 73.8, y: 33), control2: CGPoint(x: 81.8, y: 25.7))
        path.addCurve(to: CGPoint(x: 98.1, y: 49.2), control1: CGPoint(x: 87.7, y: 34.3), control2: CGPoint(x: 91.7, y: 41))
        path.addCurve(to: CGPoint(x: 102.7, y: 81.6), control1: CGPoint(x: 105.1, y: 58.2), control2: CGPoint(x: 106.2, y: 69.5))
        path.addCurve(to: CGPoint(x: 60, y: 114), control1: CGPoint(x: 96.9, y: 101.5), control2: CGPoint(x: 81.7, y: 114))
        path.closeSubpath()
        return path
    }

    nonisolated static func transform(for rect: CGRect) -> CGAffineTransform {
        CGAffineTransform(
            a: rect.width / 120, b: 0,
            c: 0, d: rect.height / 120,
            tx: rect.minX, ty: rect.minY
        )
    }

    nonisolated static func eye(centerX: CGFloat, openness: CGFloat, smile: CGFloat) -> Path {
        let centerY: CGFloat = 79
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: centerX + x, y: centerY + (y - centerY) * openness)
        }
        func blend(_ open: CGPoint, _ happy: CGPoint) -> CGPoint {
            CGPoint(
                x: open.x + (happy.x - open.x) * smile,
                y: open.y + (happy.y - open.y) * smile
            )
        }

        let open = [
            point(-4.5, 79), point(-4.5, 75.7), point(-2.5, 73), point(0, 73),
            point(2.5, 73), point(4.5, 75.7), point(4.5, 79),
            point(4.5, 82.3), point(2.5, 85), point(0, 85),
            point(-2.5, 85), point(-4.5, 82.3)
        ]
        let happy = [
            CGPoint(x: centerX - 8, y: 81), CGPoint(x: centerX - 7, y: 76.5),
            CGPoint(x: centerX - 4, y: 74), CGPoint(x: centerX, y: 74),
            CGPoint(x: centerX + 4, y: 74), CGPoint(x: centerX + 7, y: 76.5),
            CGPoint(x: centerX + 8, y: 81), CGPoint(x: centerX + 6, y: 83),
            CGPoint(x: centerX + 3, y: 78.5), CGPoint(x: centerX, y: 78.5),
            CGPoint(x: centerX - 3, y: 78.5), CGPoint(x: centerX - 6, y: 83)
        ]
        let points = zip(open, happy).map(blend)

        var path = Path()
        path.move(to: points[0])
        path.addCurve(to: points[3], control1: points[1], control2: points[2])
        path.addCurve(to: points[6], control1: points[4], control2: points[5])
        path.addCurve(to: points[9], control1: points[7], control2: points[8])
        path.addCurve(to: points[0], control1: points[10], control2: points[11])
        path.closeSubpath()
        return path
    }
}
