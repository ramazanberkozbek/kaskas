#if DEBUG
import Foundation
import Testing
@testable import Kaskas

struct SessionDebugInspectionTests {
    private let base = Date(timeIntervalSinceReferenceDate: 0)

    private func time(_ minute: Int, _ second: Double = 0) -> Date {
        base.addingTimeInterval(Double(minute * 60) + second)
    }

    @Test
    func listsEveryKindInsideAGapWithoutChangingTheGroupingDecision() throws {
        let first = ActivityInterval(kind: .studying, startedAt: time(0), endedAt: time(10))
        let second = ActivityInterval(kind: .studying, startedAt: time(13), endedAt: time(20))
        let breakPart = ActivityInterval(kind: .breakTime, startedAt: time(10), endedAt: time(12))
        let pausedPart = ActivityInterval(kind: .kaskasPaused, startedAt: time(12), endedAt: time(13))
        let session = try #require(StudySessionGrouping.group([first, second]).first)
        let gap = try #require(SessionDebugInspection.gap(before: 1, in: session))

        #expect(gap.duration == 180)
        #expect(!gap.splitsSession)
        #expect(gap.countsAsInterruption)
        #expect(gap.fillers(in: [first, pausedPart, breakPart, second]).map(\.kind) == [.breakTime, .kaskasPaused])
        #expect(SessionDebugInspection.endingKind(of: first, in: [first, breakPart]) == "breakTime")
    }

    @Test
    func showsZeroSecondGapAndSubsecondOverlap() throws {
        let first = ActivityInterval(kind: .studying, startedAt: time(0), endedAt: time(10))
        let touching = ActivityInterval(kind: .studying, startedAt: time(10), endedAt: time(11))
        let overlapping = ActivityInterval(kind: .studying, startedAt: time(10, 0.015), endedAt: time(11))
        let session = try #require(StudySessionGrouping.group([first, touching, overlapping]).first)
        let gap = try #require(SessionDebugInspection.gap(before: 1, in: session))

        #expect(gap.duration == 0)
        #expect(!gap.countsAsInterruption)
        #expect(SessionDebugInspection.overlaps(of: 1, in: session).contains { $0.contains("#3: 59,985 sn") })
        #expect(SessionDebugFormat.rawSeconds(0.015) == "0,015")
    }

    @Test
    func actualBreakDecisionIncludesFormattedSecondsBelowTheGapThreshold() {
        let gap = SessionDebugGap(start: time(10), end: time(12, 0.015))
        let entry = BreakHistoryEntry(
            id: "debug-break", occurredAt: gap.end, startedAt: gap.start,
            focusStartedAt: nil, focusedDuration: nil,
            outcome: .completed, source: .scheduled
        )

        #expect(!gap.splitsSession)
        #expect(gap.decisionText(breakEntries: [entry]) == "120,015 sn · gerçek mola → böldü")
    }

    @Test
    func boundaryExplainsWhyNearFiveMinuteBreakSplitSessions() throws {
        let first = ActivityInterval(kind: .studying, startedAt: time(0), endedAt: time(10))
        let second = ActivityInterval(kind: .studying, startedAt: time(14, 15.3), endedAt: time(20))
        let sessions = StudySessionGrouping.group([first, second])
        let gap = try #require(SessionDebugInspection.boundary(after: sessions[0], next: sessions[1]))

        #expect(gap.duration > 255 && gap.duration < 256)
        #expect(gap.splitsSession)
        #expect(gap.countsAsInterruption)
        #expect(gap.decisionText().contains("≥ 240 → böldü"))
    }
}
#endif
