import Foundation
import Testing
@testable import Kaskas

struct StudySessionCategoryTests {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000_000)

    private func focus(_ from: Double = 0, _ to: Double = 1000) -> ActivityInterval {
        .init(kind: .studying, startedAt: start.addingTimeInterval(from), endedAt: start.addingTimeInterval(to))
    }

    private func segment(_ category: String, _ from: Double, _ to: Double,
                         source: CategoryResolution.Source = .builtInRule,
                         id: UUID = UUID(), app: String = "test.app") -> AppUsageSegment {
        .init(id: id, app: .init(bundleID: app, name: app),
              resolution: .init(categoryID: category, source: source, ruleKey: app),
              startedAt: start.addingTimeInterval(from), endedAt: start.addingTimeInterval(to))
    }

    private func summary(_ usage: [AppUsageSegment], intervals: [ActivityInterval]? = nil) -> StudySessionCategorySummary {
        .init(usage: .make(intervals: intervals ?? [focus()], usage: usage, from: start, to: start.addingTimeInterval(1000)))
    }

    @Test func browserAndEditorAreMixedWithoutWebContext() {
        let value = summary([segment("browsing", 0, 500), segment("coding", 500, 900),
                             segment("other", 900, 1000, source: .unmatched)])
        #expect(value.decision == .mixed)
        #expect(value.usage.resolvedDuration == 900)
        #expect(value.usage.total == 1000)
        #expect(value.usage.entries.map(\.duration) == [500, 400])
        #expect(value.usage.undetected == 100)
        #expect(value.usage.undetectedApps.map(\.duration) == [100])
        #expect(value.usage.unrecordedDuration == 0)
    }

    @Test func multipleToolsAggregateByCategory() {
        let value = summary([segment("coding", 0, 350, app: "vscode"), segment("coding", 350, 650, app: "xcode"),
                             segment("browsing", 650, 900), segment("other", 900, 1000, source: .unmatched)])
        #expect(value.decision == .dominant(categoryID: "coding"))
        #expect(value.usage.entries.first?.duration == 650)
    }

    @Test(arguments: [599.0, 600.0]) func dominanceUsesUnroundedDurations(_ coding: Double) {
        let value = summary([segment("coding", 0, coding), segment("design", coding, 1000)])
        #expect(value.decision == (coding < 600 ? .mixed : .dominant(categoryID: "coding")))
    }

    @Test(arguments: [699.0, 700.0]) func minimumCoverageIncludesUndetectedTime(_ detected: Double) {
        let value = summary([segment("coding", 0, detected)])
        #expect(value.decision == (detected < 700 ? .insufficient(.lowCoverage) : .dominant(categoryID: "coding")))
        #expect(value.usage.undetected == 1000 - detected)
    }

    @Test(arguments: [CategoryResolution.Source.unmatched, .ambiguous, .suppressed])
    func unresolvedOtherDoesNotDetermineAWorkCategory(_ source: CategoryResolution.Source) {
        #expect(summary([segment("coding", 0, 400), segment("other", 400, 1000, source: source)]).decision
                == .insufficient(.lowCoverage))
    }

    @Test func explicitOtherIsARealAssignment() {
        #expect(summary([segment("other", 0, 800, source: .userRule), segment("coding", 800, 1000)]).decision
                == .dominant(categoryID: "other"))
        // Unknown time must not tip an explicit Other rule over the dominance threshold.
        #expect(summary([segment("other", 0, 400, source: .userRule), segment("other", 400, 650, source: .unmatched),
                         segment("coding", 650, 1000)]).decision == .mixed)
    }

    @Test func missingAndShortSessionsRemainUndetermined() {
        #expect(summary([]).decision == .insufficient(.tooShort))
        #expect(summary([segment("coding", 0, 59)], intervals: [focus(0, 59)]).decision == .insufficient(.tooShort))
        #expect(summary([segment("coding", 0, 60)], intervals: [focus(0, 60)]).decision == .dominant(categoryID: "coding"))
        #expect(summary([segment("design", 0, 500), segment("coding", 500, 1000)]).decision == .mixed)
    }

    @Test func idleGapsAndReplaysUseTheSameClippingForCoverageAndDistribution() {
        let record = segment("coding", 0, 600)
        let value = summary([record, record, segment("browsing", 300, 900)],
                            intervals: [focus(0, 400), focus(800, 1000)])
        #expect(value.usage.total == 600)
        #expect(value.usage.resolvedDuration == 500)
        #expect(value.usage.undetected == 100)
        #expect(value.decision == .dominant(categoryID: "coding"))
        #expect(value.usage.entries.reduce(0) { $0 + $1.duration } + value.usage.undetected == value.usage.total)
    }

    @Test func unresolvedOverlapWinnerCannotIncreaseResolvedCoverage() throws {
        let winnerID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let loserID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        let value = summary([segment("other", 0, 1000, source: .unmatched, id: winnerID),
                             segment("coding", 0, 1000, id: loserID)])
        #expect(value.usage.resolvedDuration == 0)
        #expect(value.usage.entries.isEmpty)
        #expect(value.usage.undetected == 1000)
        #expect(value.usage.undetectedApps.map(\.duration) == [1000])
        #expect(value.usage.unrecordedDuration == 0)
        #expect(value.decision == .insufficient(.tooShort))
    }

    @Test func manualIDSurvivesRelaunchAndNoteOnlyEditsPreserveAutomaticSelection() throws {
        let suite = "StudySessionCategoryTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let session = try #require(StudySessionGrouping.group([focus()]).first)
        let store = SessionStore(defaults: defaults)
        store.save(categorySelection: .automatic, categoryName: nil, note: "Not", for: session)
        #expect(SessionCategorySelection(annotation: store.annotation(for: session)) == .automatic)
        #expect(store.annotation(for: session).note == "Not")
        store.save(categorySelection: .category(id: "design"), categoryName: "Tasarım", note: "Not", for: session)
        let reopened = SessionStore(defaults: defaults)
        #expect(SessionCategorySelection(annotation: reopened.annotation(for: session)) == .category(id: "design"))
        // Presentation resolves names by ID, not the saved display name.
        let registry = CategoryRegistry(defaults: defaults)
        let presentation = SessionCategoryPresentation(selection: .init(annotation: reopened.annotation(for: session)),
            summary: summary([segment("coding", 0, 1000)]), registry: registry, isOngoing: false)
        #expect(presentation.title == registry.historicalCategory(for: "design")?.name)
    }

    @Test func automaticRestorationPreservesIndividualNotesAndLegacyData() throws {
        let suite = "StudySessionCategoryTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = focus(0, 400), second = focus(450, 1000)
        let old: [String: [String: String]] = [first.sessionKey: ["category": "Proje", "note": "İlk not"],
                                            second.sessionKey: ["category": "Ders", "note": "İkinci not"]]
        defaults.set(try JSONSerialization.data(withJSONObject: old), forKey: "sessionAnnotations")
        let store = SessionStore(defaults: defaults)
        let session = try #require(StudySessionGrouping.group([first, second]).first)
        #expect(store.annotation(for: session).category == "Proje, Ders")
        #expect(store.annotation(for: session).categoryID == nil)
        store.save(categorySelection: .automatic, categoryName: nil, note: "İlk not\n\nİkinci not", for: session)
        #expect(!store.annotation(for: session).hasManualCategory)
        #expect(store.annotation(for: first).note == "İlk not")
        #expect(store.annotation(for: second).note == "İkinci not")
        store.save(categorySelection: .category(id: "coding"), categoryName: "Yazılım", note: "İlk not\n\nİkinci not", for: session)
        #expect(store.annotation(for: session).categoryID == "coding")
        #expect(store.annotation(for: session).note == "İlk not\n\nİkinci not")
    }

    @Test func automaticLabelsDoNotMakeShortSessionsVisible() throws {
        let session = try #require(StudySessionGrouping.group([focus(0, 120)]).first)
        #expect(summary([segment("coding", 0, 120)], intervals: session.intervals).decision == .dominant(categoryID: "coding"))
        #expect(!session.isVisible(showShortSessions: false, hasAnnotation: false, activeStartedAt: nil))
    }

    @Test func manualCategoryUsesCurrentNameAndArchivedMetadataAfterDeletion() throws {
        let suite = "StudySessionCategoryTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let registry = CategoryRegistry(defaults: defaults)
        let category = registry.addOrUpdateCategory(name: "Ders", iconName: "book", colorName: "blue")
        let store = SessionStore(defaults: defaults)
        let session = try #require(StudySessionGrouping.group([focus()]).first)
        store.save(categorySelection: .category(id: category.id), categoryName: category.name, note: "", for: session)
        _ = registry.addOrUpdateCategory(name: "Araştırma", iconName: "book", colorName: "green", id: category.id)
        let selection = SessionCategorySelection(annotation: store.annotation(for: session))
        let automatic = summary([segment("coding", 0, 1000)])
        #expect(SessionCategoryPresentation(selection: selection, summary: automatic, registry: registry,
                                            isOngoing: false).title == "Araştırma")
        registry.removeCategory(id: category.id)
        let restored = CategoryRegistry(defaults: defaults)
        #expect(restored.category(for: category.id) == nil)
        #expect(SessionCategoryPresentation(selection: selection, summary: automatic, registry: restored,
                                            isOngoing: false).title == "Araştırma")
        #expect(store.annotation(for: session).categoryID == category.id)
    }

    @Test func noteOnlyEditKeepsDistinctManualAssignmentsOnGroupedIntervals() throws {
        let suite = "StudySessionCategoryTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SessionStore(defaults: defaults)
        let first = focus(0, 400), second = focus(450, 1000)
        let session = try #require(StudySessionGrouping.group([first, second]).first)
        store.save(annotation: .init(category: "Yazılım", note: "İlk", categoryID: "coding"), for: first)
        store.save(annotation: .init(category: "Tasarım", note: "İkinci", categoryID: "design"), for: second)
        let selection = SessionCategorySelection(annotation: store.annotation(for: session))
        #expect(selection == .legacy(label: "Yazılım, Tasarım"))
        store.save(categorySelection: selection, categoryName: nil, note: "Yeni not", for: session)
        #expect(store.annotation(for: first).categoryID == "coding")
        #expect(store.annotation(for: second).categoryID == "design")
        #expect(store.annotation(for: session).note == "Yeni not")
    }
}
