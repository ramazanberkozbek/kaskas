import Foundation
import Testing
@testable import Kaskas

struct DashboardCategorySnapshotTests {
    @Test func refreshUpdatesOngoingSessionsWithoutChangingThePreviousSnapshot() throws {
        let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let app = ForegroundApp(bundleID: "com.apple.dt.Xcode", name: "Xcode")
        func snapshot(endingAt seconds: Double, resolution: CategoryResolution) -> DashboardCategorySnapshot {
            let end = start.addingTimeInterval(seconds)
            let intervals = [ActivityInterval(kind: .studying, startedAt: start, endedAt: end)]
            let usage = [AppUsageSegment(id: UUID(), app: app, resolution: resolution, startedAt: start, endedAt: end)]
            return .make(intervals: intervals, appUsage: usage, sessions: StudySessionGrouping.group(intervals), from: start, to: end)
        }
        let before = snapshot(endingAt: 120, resolution: .unmatched)
        let after = snapshot(endingAt: 180, resolution: .init(categoryID: "coding", source: .userRule, ruleKey: nil))
        let beforeSession = try #require(before.sessions.first)
        let afterSession = try #require(after.sessions.first)
        #expect(beforeSession.id == afterSession.id)
        #expect(beforeSession.summary.usage == before.usage)
        #expect(afterSession.summary.usage == after.usage)
        #expect(beforeSession.summary.usage.total == 120)
        #expect(beforeSession.summary.usage.undetected == 120)
        #expect(afterSession.summary.usage.total == 180)
        #expect(afterSession.summary.decision == .dominant(categoryID: "coding"))
    }

    @Test func sessionSummariesExcludeInterruptionsAndKeepIndependentAppDistributions() throws {
        let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
        func focus(_ from: Double, _ to: Double) -> ActivityInterval {
            .init(kind: .studying, startedAt: start.addingTimeInterval(from), endedAt: start.addingTimeInterval(to))
        }
        let intervals = [focus(0, 120), focus(150, 240), focus(600, 720)]
        let usage = [AppUsageSegment(id: UUID(), app: .init(bundleID: "xcode", name: "Xcode"),
            resolution: .init(categoryID: "coding", source: .builtInRule, ruleKey: nil),
            startedAt: start, endedAt: start.addingTimeInterval(600)),
            AppUsageSegment(id: UUID(), app: .init(bundleID: "safari", name: "Safari"), resolution: .unmatched,
            startedAt: start.addingTimeInterval(600), endedAt: start.addingTimeInterval(720))]
        let snapshot = DashboardCategorySnapshot.make(intervals: intervals, appUsage: usage,
            sessions: StudySessionGrouping.group(intervals), from: start, to: start.addingTimeInterval(720))
        #expect(snapshot.usage.total == 330)
        #expect(snapshot.sessions.count == 2)
        let coding = try #require(snapshot.sessions.first)
        #expect(coding.summary.usage.total == 210)
        #expect(coding.summary.usage.entries.flatMap(\.apps).map(\.duration) == [210])
        let undetected = try #require(snapshot.sessions.last)
        #expect(undetected.summary.usage.total == 120)
        #expect(undetected.summary.usage.undetectedApps.map(\.app.name) == ["Safari"])
        #expect(snapshot.sessions.reduce(0) { $0 + $1.summary.usage.total } == snapshot.usage.total)
    }

    @Test func snapshotForSelectedPastDayIncludesOnlyThatDaysIntervalsAndSessions() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: today))
        let yesterdayEnd = today

        let yesterdayFocus = ActivityInterval(
            kind: .studying,
            startedAt: yesterday.addingTimeInterval(3600),
            endedAt: yesterday.addingTimeInterval(7200)
        )
        let todayFocus = ActivityInterval(
            kind: .studying,
            startedAt: today.addingTimeInterval(1800),
            endedAt: today.addingTimeInterval(3600)
        )
        let app = ForegroundApp(bundleID: "com.apple.dt.Xcode", name: "Xcode")
        let usage = [
            AppUsageSegment(
                id: UUID(), app: app,
                resolution: .init(categoryID: "coding", source: .builtInRule, ruleKey: nil),
                startedAt: yesterday.addingTimeInterval(3600),
                endedAt: yesterday.addingTimeInterval(7200)
            ),
            AppUsageSegment(
                id: UUID(), app: app,
                resolution: .init(categoryID: "coding", source: .builtInRule, ruleKey: nil),
                startedAt: today.addingTimeInterval(1800),
                endedAt: today.addingTimeInterval(3600)
            )
        ]

        let allIntervals = [yesterdayFocus, todayFocus]
        let yesterdayIntervals = allIntervals.filter { $0.startedAt >= yesterday && $0.startedAt < yesterdayEnd }
        let yesterdaySessions = StudySessionGrouping.group(yesterdayIntervals)

        let snapshot = DashboardCategorySnapshot.make(
            intervals: allIntervals,
            appUsage: usage,
            sessions: yesterdaySessions,
            from: yesterday,
            to: yesterdayEnd
        )

        #expect(snapshot.usage.total == 3600)
        #expect(snapshot.sessions.count == 1)
        let session = try #require(snapshot.sessions.first)
        #expect(session.value.startedAt == yesterdayFocus.startedAt)
        #expect(session.summary.usage.total == 3600)
        #expect(session.summary.decision == .dominant(categoryID: "coding"))
    }
}

