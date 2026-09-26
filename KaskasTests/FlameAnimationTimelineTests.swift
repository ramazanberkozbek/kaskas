import Testing
@testable import Kaskas

struct FlameAnimationTimelineTests {
    @Test
    func usesTwoPairsAndOneFinalBlink() {
        let entrance = FlameAnimationTimeline.entranceDuration
        let closedTimes = [0.425, 0.675, 1.295, 1.545, 2.165]
        let restTimes = [0.55, 0.95, 1.42, 1.8, 2.35]

        for time in closedTimes {
            #expect(abs(FlameAnimationTimeline.pose(at: entrance + time, reduceMotion: false).eyeOpenness - 0.09) < 0.001)
        }
        for time in restTimes {
            #expect(FlameAnimationTimeline.pose(at: entrance + time, reduceMotion: false).eyeOpenness == 1)
        }
    }

    @Test
    func breathesVerticallyAndFinishesAfterSmileHold() {
        let start = FlameAnimationTimeline.pose(at: 0, reduceMotion: false)
        let inhale = FlameAnimationTimeline.pose(at: 1.3, reduceMotion: false)
        let exhale = FlameAnimationTimeline.pose(at: 2.6, reduceMotion: false)
        let smile = FlameAnimationTimeline.pose(at: 3.3, reduceMotion: false)
        let end = FlameAnimationTimeline.pose(at: FlameAnimationTimeline.totalDuration, reduceMotion: false)

        #expect(abs(start.breathingScale - 1) < 0.001)
        #expect(abs(inhale.breathingScale - 1.05) < 0.001)
        #expect(abs(exhale.breathingScale - 1) < 0.001)
        #expect(smile.smileProgress == 1)
        #expect(!smile.finished)
        #expect(end.finished)
        #expect(end.opacity == 0)
    }

    @Test
    func reducedMotionKeepsStaticSmile() {
        let pose = FlameAnimationTimeline.pose(at: 2, reduceMotion: true)

        #expect(pose.eyeOpenness == 1)
        #expect(pose.smileProgress == 1)
        #expect(pose.breathingScale == 1)
        #expect(pose.appearanceScale == 1)
        #expect(!pose.finished)
    }
}
