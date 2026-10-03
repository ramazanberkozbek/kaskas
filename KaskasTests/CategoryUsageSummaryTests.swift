import Foundation
import Testing
@testable import Kaskas

struct CategoryUsageSummaryTests {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
    private let xcode = ForegroundApp(bundleID: "com.apple.dt.Xcode", name: "Xcode")
    private let code = ForegroundApp(bundleID: "com.microsoft.VSCode", name: "Visual Studio Code")
    private let safari = ForegroundApp(bundleID: "com.apple.Safari", name: "Safari")

    private func focus(_ from: Double, _ to: Double) -> ActivityInterval {
        .init(kind: .studying, startedAt: start.addingTimeInterval(from), endedAt: start.addingTimeInterval(to))
    }

    private func segment(_ app: ForegroundApp, _ category: String, _ from: Double, _ to: Double,
                         source: CategoryResolution.Source = .builtInRule) -> AppUsageSegment {
        .init(id: UUID(), app: app,
              resolution: .init(categoryID: category, source: source, ruleKey: app.bundleID),
              startedAt: start.addingTimeInterval(from), endedAt: start.addingTimeInterval(to))
    }

    @Test func appBreakdownCombinesHistoricalCategoriesAndUnresolvedVisitsWithoutInventingUsage() {
        let renamedXcode = ForegroundApp(bundleID: " COM.APPLE.DT.XCODE ", name: "Renamed Xcode")
        let summary = CategoryUsageSummary.make(intervals: [focus(0, 300)], usage: [
            segment(xcode, "coding", 0, 60),
            segment(renamedXcode, "design", 60, 120),
            segment(xcode, "other", 120, 180, source: .unmatched),
            segment(safari, "browsing", 180, 240)
        ], from: start, to: start.addingTimeInterval(300))

        #expect(summary.apps.count == 2)
        #expect(summary.apps.map(\.duration) == [180, 60])
        #expect(summary.apps.first?.id == "bundle:com.apple.dt.xcode")
        #expect(summary.apps.reduce(0) { $0 + $1.duration } + summary.unrecordedDuration == summary.total)
        #expect(summary.unrecordedDuration == 60)
        #expect(CategoryUsageSummary.empty.apps.isEmpty)
    }

    @Test func repeatedAppVisitsAreCombinedAndSortedWithinEachCategory() throws {
        let summary = CategoryUsageSummary.make(intervals: [focus(0, 600)], usage: [
            segment(xcode, "coding", 0, 120), segment(code, "coding", 120, 180),
            segment(xcode, "coding", 180, 300), segment(safari, "browsing", 300, 600)
        ], from: start, to: start.addingTimeInterval(600))

        let coding = try #require(summary.entries.first { $0.categoryID == "coding" })
        #expect(coding.duration == 300)
        #expect(coding.apps.map(\.app.name) == ["Xcode", "Visual Studio Code"])
        #expect(coding.apps.map(\.duration) == [240, 60])
        let browsing = try #require(summary.entries.first { $0.categoryID == "browsing" })
        #expect(browsing.apps.map(\.app) == [safari])
        #expect(browsing.apps.map(\.duration) == [300])
    }

    @Test func appDurationsExcludeIdleGapsOverlapsReplaysAndTimeOutsideTheSession() throws {
        let first = segment(xcode, "coding", 0, 80)
        let summary = CategoryUsageSummary.make(intervals: [focus(0, 60), focus(90, 150)], usage: [
            first, first, segment(code, "coding", 50, 100), segment(safari, "browsing", 100, 160)
        ], from: start.addingTimeInterval(30), to: start.addingTimeInterval(120))

        #expect(summary.total == 60)
        #expect(summary.undetected == 0)
        let coding = try #require(summary.entries.first { $0.categoryID == "coding" })
        #expect(coding.apps.map(\.app.name) == ["Xcode", "Visual Studio Code"])
        #expect(coding.apps.map(\.duration) == [30, 10])
        let browsing = try #require(summary.entries.first { $0.categoryID == "browsing" })
        #expect(browsing.apps.map(\.duration) == [20])
        for category in summary.entries {
            #expect(category.apps.reduce(0) { $0 + $1.duration } == category.duration)
        }
    }

    @Test func appIdentityUsesBundleIDAndKeepsHistoricalCategoryAssignments() throws {
        let renamedXcode = ForegroundApp(bundleID: " COM.APPLE.DT.XCODE ", name: "Renamed Xcode")
        let differentApp = ForegroundApp(bundleID: "org.example.editor", name: "Xcode")
        let summary = CategoryUsageSummary.make(intervals: [focus(0, 240)], usage: [
            segment(xcode, "coding", 0, 60), segment(renamedXcode, "coding", 60, 120),
            segment(differentApp, "coding", 120, 180), segment(xcode, "design", 180, 240)
        ], from: start, to: start.addingTimeInterval(240))

        let coding = try #require(summary.entries.first { $0.categoryID == "coding" })
        #expect(coding.apps.count == 2)
        #expect(coding.apps.map(\.duration) == [120, 60])
        #expect(Set(coding.apps.map(\.id)).count == 2)
        let design = try #require(summary.entries.first { $0.categoryID == "design" })
        #expect(design.apps.map(\.app) == [xcode])
        #expect(design.apps.map(\.duration) == [60])
    }

    @Test func missingBundleIDsUseAppNamesAndUndetectedTimeHasNoInventedApp() throws {
        let terminal = ForegroundApp(bundleID: nil, name: "Ghostty")
        let terminalAgain = ForegroundApp(bundleID: "", name: " ghostty ")
        let summary = CategoryUsageSummary.make(intervals: [focus(0, 180)], usage: [
            segment(terminal, "coding", 0, 30), segment(terminalAgain, "coding", 30, 60)
        ], from: start, to: start.addingTimeInterval(180))

        let coding = try #require(summary.entries.first)
        #expect(coding.apps.count == 1)
        #expect(coding.apps.first?.app.name == "Ghostty")
        #expect(coding.apps.first?.duration == 60)
        #expect(summary.undetected == 120)
        #expect(summary.undetectedApps.isEmpty)
        #expect(summary.unrecordedDuration == 120)
        let unrecorded = CategoryUsageSummary.make(intervals: [focus(0, 180)], usage: [],
            from: start, to: start.addingTimeInterval(180))
        #expect(unrecorded.entries.isEmpty)
        #expect(unrecorded.undetected == 180)
        #expect(unrecorded.undetectedApps.isEmpty)
        #expect(unrecorded.unrecordedDuration == 180)
    }

    @Test func unresolvedCategoriesKeepKnownAppsSeparateFromMissingRecords() throws {
        let terminal = ForegroundApp(bundleID: nil, name: "Ghostty")
        let summary = CategoryUsageSummary.make(intervals: [focus(0, 240)], usage: [
            segment(xcode, "coding", 0, 60),
            segment(terminal, "other", 60, 120, source: .unmatched),
            segment(safari, "other", 120, 150, source: .ambiguous),
            segment(terminal, "other", 150, 180, source: .suppressed)
        ], from: start, to: start.addingTimeInterval(240))

        #expect(summary.entries.map(\.categoryID) == ["coding"])
        #expect(summary.resolvedDuration == 60)
        #expect(summary.undetected == 180)
        #expect(summary.undetectedApps.map(\.app.name) == ["Ghostty", "Safari"])
        #expect(summary.undetectedApps.map(\.duration) == [90, 30])
        #expect(summary.unrecordedDuration == 60)
        #expect(summary.entries.reduce(0) { $0 + $1.duration } + summary.undetected == summary.total)
        #expect(summary.undetectedApps.reduce(0) { $0 + $1.duration } + summary.unrecordedDuration == summary.undetected)
    }

    @Test func explicitlyAssignedOtherRemainsSeparateFromUnresolvedUsageOfTheSameApp() throws {
        let summary = CategoryUsageSummary.make(intervals: [focus(0, 180)], usage: [
            segment(xcode, "other", 0, 60, source: .userRule),
            segment(xcode, "other", 60, 120, source: .unmatched)
        ], from: start, to: start.addingTimeInterval(180))

        let other = try #require(summary.entries.first)
        #expect(other.categoryID == "other")
        #expect(other.duration == 60)
        #expect(other.apps.map(\.duration) == [60])
        #expect(summary.undetected == 120)
        #expect(summary.undetectedApps.map(\.app) == [xcode])
        #expect(summary.undetectedApps.map(\.duration) == [60])
        #expect(summary.unrecordedDuration == 60)
    }

    @Test func unresolvedAppDurationsRespectClippingIdleOverlapsAndReplays() throws {
        let first = segment(xcode, "other", 0, 80, source: .unmatched)
        let summary = CategoryUsageSummary.make(intervals: [focus(0, 60), focus(90, 150)], usage: [
            first, first, segment(code, "coding", 50, 100),
            segment(safari, "other", 100, 160, source: .suppressed)
        ], from: start.addingTimeInterval(30), to: start.addingTimeInterval(120))

        #expect(summary.total == 60)
        #expect(summary.resolvedDuration == 10)
        #expect(summary.entries.map(\.duration) == [10])
        #expect(summary.undetected == 50)
        #expect(summary.undetectedApps.map(\.app) == [xcode, safari])
        #expect(summary.undetectedApps.map(\.duration) == [30, 20])
        #expect(summary.unrecordedDuration == 0)
    }

    @Test func spanningWinnerSkipsNestedRecordsButKeepsALaterRecordsUncoveredTail() {
        let intervals = [focus(10, 20), focus(60, 70), focus(100, 110)]
        let usage = [segment(xcode, "coding", 0, 90),
                     segment(code, "other", 20, 30, source: .unmatched),
                     segment(safari, "browsing", 30, 105)]
        let summary = CategoryUsageSummary.Timeline(usage: usage)
            .summary(intervals: intervals, from: start, to: start.addingTimeInterval(120))
        #expect(summary.total == 30)
        #expect(summary.entries.map(\.categoryID) == ["coding", "browsing"])
        #expect(summary.entries.map(\.duration) == [20, 5])
        #expect(summary.entries.flatMap(\.apps).map(\.app) == [xcode, safari])
        #expect(summary.undetected == 5)
        #expect(summary.undetectedApps.isEmpty)
        #expect(summary.unrecordedDuration == 5)
    }

    @Test func equalStartsUseUUIDPriorityAndRetainTheLosingRecordsUncoveredTail() throws {
        let winner = AppUsageSegment(id: try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001")),
            app: safari, resolution: .unmatched, startedAt: start, endedAt: start.addingTimeInterval(40))
        let loser = AppUsageSegment(id: try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000002")),
            app: xcode, resolution: .init(categoryID: "coding", source: .builtInRule, ruleKey: nil),
            startedAt: start, endedAt: start.addingTimeInterval(100))
        let summary = CategoryUsageSummary.make(intervals: [focus(0, 100)], usage: [loser, winner, winner],
            from: start, to: start.addingTimeInterval(100))
        #expect(summary.entries.map(\.duration) == [60])
        #expect(summary.entries.flatMap(\.apps).map(\.app) == [xcode])
        #expect(summary.undetectedApps.map(\.app) == [safari])
        #expect(summary.undetectedApps.map(\.duration) == [40])
        #expect(summary.unrecordedDuration == 0)
    }

    @Test func aSharedTimelineSupportsIndependentWindowsIncludingEmptyAndReversedWindows() {
        let intervals = [focus(0, 60), focus(90, 180)]
        let usage = [segment(xcode, "coding", -30, 120), segment(safari, "browsing", 100, 200)]
        let timeline = CategoryUsageSummary.Timeline(usage: usage)
        for (from, to) in [(120.0, 180.0), (30, 100), (-60, -30), (60, 90), (100, 100), (120, 100), (0, 180)] {
            let a = start.addingTimeInterval(from), b = start.addingTimeInterval(to)
            #expect(timeline.summary(intervals: intervals, from: a, to: b)
                    == CategoryUsageSummary.make(intervals: intervals, usage: usage, from: a, to: b))
        }
    }

    @Test func overlappingAndReplayedRecordsMatchAnIndependentPerSecondOracle() throws {
        // Integer boundaries let us check ownership by sampling each second instead
        // of reproducing the production merge/intersection algorithm.
        var random: UInt64 = 0xCAFE
        func next(_ limit: Int) -> Int {
            random = random &* 6364136223846793005 &+ 1442695040888963407
            return Int((random >> 32) % UInt64(limit))
        }
        let apps = [xcode, code, safari]
        for _ in 0..<100 {
            let intervals = (0..<12).map { _ in
                let from = Double(next(180) - 20)
                return ActivityInterval(kind: next(4) == 0 ? .breakTime : .studying,
                    startedAt: start.addingTimeInterval(from), endedAt: start.addingTimeInterval(from + Double(next(50))))
            }
            var usage: [AppUsageSegment] = []
            for index in 0..<40 {
                let from = Double(next(180) - 20), to = from + Double(next(80))
                let unresolved = next(3) == 0
                usage.append(.init(id: try #require(UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))),
                    app: apps[next(apps.count)],
                    resolution: .init(categoryID: unresolved ? "other" : (next(2) == 0 ? "coding" : "browsing"),
                                      source: unresolved ? .unmatched : .builtInRule, ruleKey: nil),
                    startedAt: start.addingTimeInterval(from), endedAt: start.addingTimeInterval(to)))
            }
            usage.append(contentsOf: usage.prefix(5))
            let from = next(40), to = 120 + next(40)
            let ordered = usage.sorted {
                if $0.startedAt == $1.startedAt { return $0.id.uuidString < $1.id.uuidString }
                return $0.startedAt < $1.startedAt
            }
            var categories: [String: Double] = [:], categoryApps: [String: Double] = [:], unknownApps: [String: Double] = [:]
            var total = 0.0, unrecorded = 0.0
            for second in from..<to {
                let date = start.addingTimeInterval(Double(second) + 0.5)
                guard intervals.contains(where: { $0.kind == .studying && $0.startedAt <= date && $0.endedAt > date }) else { continue }
                total += 1
                guard let record = ordered.first(where: { $0.startedAt <= date && $0.endedAt > date }) else {
                    unrecorded += 1
                    continue
                }
                let appID = CategoryUsageSummary.AppEntry(app: record.app, duration: 0).id
                if record.resolution.isResolved {
                    categories[record.resolution.categoryID, default: 0] += 1
                    categoryApps[record.resolution.categoryID + "|" + appID, default: 0] += 1
                } else { unknownApps[appID, default: 0] += 1 }
            }
            let summary = CategoryUsageSummary.make(intervals: intervals, usage: usage,
                from: start.addingTimeInterval(Double(from)), to: start.addingTimeInterval(Double(to)))
            #expect(summary.total == total)
            #expect(Dictionary(uniqueKeysWithValues: summary.entries.map { ($0.categoryID, $0.duration) }) == categories)
            #expect(Dictionary(uniqueKeysWithValues: summary.entries.flatMap { category in
                category.apps.map { (category.categoryID + "|" + $0.id, $0.duration) }
            }) == categoryApps)
            #expect(Dictionary(uniqueKeysWithValues: summary.undetectedApps.map { ($0.id, $0.duration) }) == unknownApps)
            #expect(summary.unrecordedDuration == unrecorded)
            #expect(summary.undetected == total - categories.values.reduce(0, +))
            #expect(summary.resolvedDuration == categories.values.reduce(0, +))
        }
    }
}
