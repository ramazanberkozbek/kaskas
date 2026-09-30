import Foundation
import Testing
@testable import Kaskas

struct StudySessionGroupingTests {
    private let base = Date(timeIntervalSinceReferenceDate: 0)

    private func time(_ hour: Int, _ minute: Int, _ second: Double = 0) -> Date {
        base.addingTimeInterval(Double(hour * 3600 + minute * 60) + second)
    }

    private func focus(_ startHour: Int, _ startMinute: Int, _ endHour: Int, _ endMinute: Int) -> ActivityInterval {
        ActivityInterval(
            kind: .studying,
            startedAt: time(startHour, startMinute),
            endedAt: time(endHour, endMinute)
        )
    }

    private func breakEntry(
        startedAt: Date?,
        endedAt: Date,
        outcome: BreakHistoryEntry.Outcome,
        source: BreakHistoryEntry.Source
    ) -> BreakHistoryEntry {
        BreakHistoryEntry(
            id: UUID().uuidString,
            occurredAt: endedAt,
            startedAt: startedAt,
            focusStartedAt: nil,
            focusedDuration: nil,
            outcome: outcome,
            source: source
        )
    }

    @Test
    func skippedActualBreakSplitsEvenBeforeFourMinuteThreshold() {
        let first = focus(10, 0, 10, 20)
        let second = focus(10, 23, 10, 40)
        let skip = breakEntry(
            startedAt: first.endedAt,
            endedAt: second.startedAt,
            outcome: .skipped,
            source: .manual
        )

        #expect(StudySessionGrouping.group([first, second]).count == 1)
        let sessions = StudySessionGrouping.group([first, second], breakEntries: [skip])
        #expect(sessions.count == 2)
        #expect(sessions[0].endedAt == first.endedAt)
        #expect(sessions[1].startedAt == second.startedAt)
    }

    @Test
    func completedActualBreakSplitsButIdleBreakAndWarningSkipDoNot() {
        let first = focus(10, 0, 10, 20)
        let second = focus(10, 23, 10, 40)
        let completed = breakEntry(
            startedAt: first.endedAt, endedAt: second.startedAt,
            outcome: .completed, source: .scheduled
        )
        let idle = breakEntry(
            startedAt: first.endedAt, endedAt: second.startedAt,
            outcome: .completed, source: .smartPause
        )
        let warningSkip = breakEntry(
            startedAt: nil, endedAt: time(10, 21),
            outcome: .skipped, source: .manual
        )

        #expect(StudySessionGrouping.group([first, second], breakEntries: [completed]).count == 2)
        #expect(StudySessionGrouping.group([first, second], breakEntries: [idle]).count == 1)
        #expect(StudySessionGrouping.group([first, second], breakEntries: [warningSkip]).count == 1)
    }

    @Test
    func shortGapsMergeAndSixOrNineMinuteGapsSplit() {
        let intervals = [
            focus(8, 30, 8, 38),
            focus(8, 40, 8, 59),
            focus(9, 5, 9, 25),
            focus(9, 34, 9, 40)
        ]

        let sessions = StudySessionGrouping.group(intervals)

        #expect(sessions.count == 3)
        #expect(sessions[0].focusedDuration == 27 * 60)
        #expect(sessions[0].interruptionCount == 1)
        #expect(sessions[1].startedAt == time(9, 5))
        #expect(sessions[2].startedAt == time(9, 34))
    }

    @Test
    func fourMinuteGapSplitsWhileThreeMinuteGapMergesRegardlessOfKind() {
        let intervals = [
            focus(8, 0, 8, 10),
            ActivityInterval(kind: .breakTime, startedAt: time(8, 10), endedAt: time(8, 14)),
            focus(8, 14, 8, 20),
            ActivityInterval(kind: .kaskasPaused, startedAt: time(8, 20), endedAt: time(8, 23)),
            focus(8, 23, 8, 30)
        ]

        let sessions = StudySessionGrouping.group(intervals)

        #expect(sessions.count == 2)
        #expect(sessions[0].focusedDuration == 10 * 60)
        #expect(sessions[1].focusedDuration == 13 * 60)
        #expect(sessions[1].interruptionCount == 1)
    }

    @Test
    func nearFiveMinuteGapFromSeptemberThirtiethSplits() {
        let first = ActivityInterval(
            kind: .studying,
            startedAt: time(11, 23, 29.702422),
            endedAt: time(11, 52, 47.759558)
        )
        let second = ActivityInterval(
            kind: .studying,
            startedAt: time(11, 57, 3.059218),
            endedAt: time(12, 5, 28.148418)
        )
        let gap = second.startedAt.timeIntervalSince(first.endedAt)

        #expect(abs(gap - 255.29966) < 0.001)
        #expect(StudySessionGrouping.group([first, second]).count == 2)
    }

    @Test
    func overlappingRecordsUseTheirUnionAndDoNotInventAnInterruption() {
        let intervals = [
            ActivityInterval(kind: .studying, startedAt: time(9, 11, 14), endedAt: time(9, 22, 14)),
            ActivityInterval(kind: .studying, startedAt: time(9, 11, 14), endedAt: time(9, 25, 57))
        ]

        let sessions = StudySessionGrouping.group(intervals)

        #expect(sessions.count == 1)
        #expect(sessions[0].intervals.count == 2)
        #expect(sessions[0].segments.count == 1)
        #expect(sessions[0].focusedDuration == 14 * 60 + 43)
        #expect(sessions[0].interruptionCount == 0)
    }

    @Test
    func lateMorningSequenceFormsOneSessionAfterShortBreaks() {
        let intervals = [
            focus(10, 4, 10, 8),
            focus(10, 22, 10, 53),
            focus(10, 56, 11, 11),
            ActivityInterval(kind: .studying, startedAt: time(11, 11, 30), endedAt: time(11, 19)),
            focus(11, 22, 11, 44)
        ]

        let sessions = StudySessionGrouping.group(intervals)

        #expect(sessions.count == 2)
        #expect(sessions[0].focusedDuration == 4 * 60)
        #expect(!sessions[0].isVisible(showShortSessions: false, hasAnnotation: false, activeStartedAt: nil))
        #expect(sessions[0].isVisible(showShortSessions: true, hasAnnotation: false, activeStartedAt: nil))
        #expect(sessions[0].isVisible(showShortSessions: false, hasAnnotation: true, activeStartedAt: nil))
        #expect(sessions[1].startedAt == time(10, 22))
        #expect(sessions[1].endedAt == time(11, 44))
        #expect(sessions[1].focusedDuration == 75 * 60 + 30)
        #expect(sessions[1].interruptionCount == 3)
    }

    @Test
    func onlyGapsOfAtLeastThirtySecondsCountAsInterruptions() {
        let intervals = [
            focus(11, 0, 11, 10),
            ActivityInterval(kind: .studying, startedAt: time(11, 10), endedAt: time(11, 10, 30)),
            ActivityInterval(kind: .studying, startedAt: time(11, 10, 59.999), endedAt: time(11, 11, 30)),
            focus(11, 12, 11, 20)
        ]

        let session = StudySessionGrouping.group(intervals)[0]

        #expect(session.segments.count == 3)
        #expect(session.interruptionCount == 1)
        #expect(abs(session.focusedDuration - (10 * 60 + 30 + 30.001 + 8 * 60)) < 0.001)
    }

    @Test
    func septemberThirtiethMorningSplitsAtElevenFiftyTwoWithTwoRealInterruptions() {
        let intervals = [
            ActivityInterval(kind: .studying, startedAt: time(10, 22, 4.446717), endedAt: time(10, 53, 36.858733)),
            ActivityInterval(kind: .studying, startedAt: time(10, 56, 29.276357), endedAt: time(11, 11, 25.008517)),
            ActivityInterval(kind: .studying, startedAt: time(11, 11, 30.553901), endedAt: time(11, 19, 12.251929)),
            ActivityInterval(kind: .studying, startedAt: time(11, 22, 33.577233), endedAt: time(11, 23, 0.577619)),
            ActivityInterval(kind: .studying, startedAt: time(11, 23, 29.702422), endedAt: time(11, 52, 47.759558)),
            ActivityInterval(kind: .studying, startedAt: time(11, 57, 3.059218), endedAt: time(12, 5, 28.148418))
        ]

        let sessions = StudySessionGrouping.group(intervals)

        #expect(sessions.count == 2)
        #expect(sessions[0].startedAt == intervals[0].startedAt)
        #expect(sessions[0].endedAt == intervals[4].endedAt)
        #expect(sessions[0].segments.count == 5)
        #expect(sessions[0].interruptionCount == 2)
        #expect(abs(sessions[0].focusedDuration - 5034.899306) < 0.001)
        #expect(sessions[1].startedAt == intervals[5].startedAt)
        #expect(sessions[1].interruptionCount == 0)
    }

    @Test
    func activeZeroLengthIntervalWaitsToAppear() {
        let start = time(12, 0)
        let interval = ActivityInterval(kind: .studying, startedAt: start, endedAt: start)
        let session = StudySessionGrouping.group([interval])[0]
        let brief = ActivityInterval(kind: .studying, startedAt: start, endedAt: start.addingTimeInterval(30))
        let briefSession = StudySessionGrouping.group([brief])[0]

        #expect(session.isOngoing(startedAt: start))
        #expect(!session.isVisible(showShortSessions: true, hasAnnotation: false, activeStartedAt: start))
        #expect(!briefSession.isVisible(showShortSessions: true, hasAnnotation: false, activeStartedAt: start))
        #expect(session.isVisible(showShortSessions: true, hasAnnotation: true, activeStartedAt: start))
    }

    @Test
    @MainActor
    func growingLivePieceKeepsSessionIdentityAndFirstPieceNote() throws {
        let suiteName = "StudySessionGroupingTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SessionStore(defaults: defaults)
        let first = focus(10, 0, 10, 8)
        let liveStart = time(10, 10)
        let earlyLive = ActivityInterval(kind: .studying, startedAt: liveStart, endedAt: time(10, 11))
        let laterLive = ActivityInterval(kind: .studying, startedAt: liveStart, endedAt: time(10, 16))
        let annotation = SessionAnnotation(category: "Proje", note: "Süren çalışma")
        store.save(annotation: annotation, for: first)

        let early = try #require(StudySessionGrouping.group([first, earlyLive]).first)
        let later = try #require(StudySessionGrouping.group([first, laterLive]).first)

        #expect(early.id == later.id)
        #expect(later.isOngoing(startedAt: liveStart))
        #expect(later.focusedDuration == 14 * 60)
        #expect(store.annotation(for: later) == annotation)
    }

    @Test
    @MainActor
    func secondaryNotesSurviveGroupingAndAConnectingInterval() throws {
        let suiteName = "StudySessionGroupingTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SessionStore(defaults: defaults)
        let first = focus(10, 0, 10, 8)
        let connector = focus(10, 8, 10, 12)
        let second = focus(10, 14, 10, 20)
        store.save(annotation: SessionAnnotation(category: "Proje", note: "İlk not"), for: first)
        store.save(annotation: SessionAnnotation(category: "Ders", note: "İkinci not"), for: second)

        #expect(StudySessionGrouping.group([first, second]).count == 2)
        let connected = try #require(StudySessionGrouping.group([first, connector, second]).first)
        #expect(connected.intervals.count == 3)
        #expect(connected.id == first.sessionKey)
        #expect(store.annotation(for: connected) == SessionAnnotation(category: "Proje, Ders", note: "İlk not\n\nİkinci not"))

        store.save(annotation: store.annotation(for: connected), for: connected)
        #expect(store.annotation(for: connected).note == "İlk not\n\nİkinci not")
        #expect(store.annotation(for: second) == SessionAnnotation())
    }
}
