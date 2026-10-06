import Foundation

struct FlameAnimationTimeline {
    static let entranceDuration = 0.5
    static let eyeDuration = 3.41
    static let exitDuration = 0.38
    static let totalDuration = entranceDuration + eyeDuration + exitDuration

    struct Pose {
        let eyeOpenness: Double
        let smileProgress: Double
        let breathingScale: Double
        let appearanceScale: Double
        let opacity: Double
        let finished: Bool
    }

    static func pose(at elapsed: TimeInterval, reduceMotion: Bool) -> Pose {
        let time = max(0, elapsed)
        if reduceMotion {
            return Pose(
                eyeOpenness: 1,
                smileProgress: 1,
                breathingScale: 1,
                appearanceScale: 1,
                opacity: time < totalDuration ? 1 : 0,
                finished: time >= totalDuration
            )
        }

        let eyeTime = time - entranceDuration
        let exitProgress = ease(progress(time - entranceDuration - eyeDuration, over: exitDuration))
        let entranceProgress = ease(progress(time, over: entranceDuration))
        let eye = eyePose(at: eyeTime)
        let breath = 1 + 0.05 * (1 - cos(2 * .pi * time / 2.6)) / 2

        return Pose(
            eyeOpenness: eye.openness,
            smileProgress: eye.smile,
            breathingScale: breath,
            appearanceScale: (0.18 + 0.82 * entranceProgress) * (1 - 0.88 * exitProgress),
            opacity: entranceProgress * (1 - exitProgress),
            finished: time >= totalDuration
        )
    }

    /// The cursor icon only blinks: its silhouette, size and opacity stay fixed.
    static func cursorPose(at elapsed: TimeInterval, reduceMotion: Bool) -> Pose {
        let eye = eyePose(at: max(0, elapsed).truncatingRemainder(dividingBy: eyeDuration))
        return Pose(eyeOpenness: reduceMotion ? 1 : eye.openness, smileProgress: 0,
                    breathingScale: 1, appearanceScale: 1, opacity: 1, finished: false)
    }

    private static func eyePose(at time: TimeInterval) -> (openness: Double, smile: Double) {
        let blinks: [(close: Double, open: Double)] = [
            (0.36, 0.425), (0.61, 0.675),
            (1.23, 1.295), (1.48, 1.545),
            (2.10, 2.165)
        ]

        for blink in blinks {
            if time >= blink.close && time < blink.open {
                return (1 - 0.91 * ease(progress(time - blink.close, over: 0.065)), 0)
            }
            if time >= blink.open && time < blink.open + 0.075 {
                return (0.09 + 0.91 * ease(progress(time - blink.open, over: 0.075)), 0)
            }
        }

        return (1, ease(progress(time - 2.47, over: 0.24)))
    }

    private static func progress(_ elapsed: Double, over duration: Double) -> Double {
        min(1, max(0, elapsed / duration))
    }

    private static func ease(_ value: Double) -> Double {
        value < 0.5 ? 2 * value * value : 1 - pow(-2 * value + 2, 2) / 2
    }
}
