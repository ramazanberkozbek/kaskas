import AppKit
import Synchronization
import Testing
@testable import Kaskas

@MainActor
struct CategoryApplicationWorkerTests {
    @Test
    func concurrentColdDiscoveryCachesNegativeChecksAndRefreshRetries() async {
        let scans = Mutex(0)
        let checks = Mutex(0)
        let worker = CategoryApplicationWorker(diskDiscovery: {
            #expect(!Thread.isMainThread)
            scans.withLock { $0 += 1 }
            return []
        }, applicationPath: { _ in
            #expect(!Thread.isMainThread)
            checks.withLock { $0 += 1 }
            return nil
        })
        let missing = CategoryRule(appIdentifier: "test.absent.application", displayName: "Absent", categoryId: "coding", isDefault: true)
        async let first = worker.discover(rules: [missing, missing])
        async let second = worker.discover(rules: [missing])
        let snapshots = await (first, second)
        #expect(snapshots.0.installed[missing.appIdentifier] == false)
        #expect(snapshots.1.installed == snapshots.0.installed)
        #expect(scans.withLock { $0 } == 1)
        #expect(checks.withLock { $0 } == 1)
        _ = await worker.discover(rules: [missing], forceRefresh: true)
        #expect(scans.withLock { $0 } == 2)
        #expect(checks.withLock { $0 } == 2)
    }

    @Test
    func discoveredNamesAndBundleIDsAvoidFallbackAndPreserveLookupSemantics() async {
        let checks = Mutex(0)
        let worker = CategoryApplicationWorker(diskDiscovery: {
            [.init(id: "test.present", name: "Present Tool", bundleId: "test.present", path: "/Applications/Present Tool.app")]
        }, applicationPath: { id in
            checks.withLock { $0 += 1 }
            return id == "test.fallback" ? "/Applications/Fallback.app" : nil
        })
        let rules = [
            CategoryRule(appIdentifier: "TEST.PRESENT", displayName: "Other Name", categoryId: "coding"),
            CategoryRule(appIdentifier: "test.name-match", displayName: "PRESENT TOOL", categoryId: "coding"),
            CategoryRule(appIdentifier: "test.fallback", displayName: "Fallback", categoryId: "coding")
        ]
        let snapshot = await worker.discover(rules: rules)
        #expect(snapshot.installed.values.allSatisfy { $0 })
        #expect(checks.withLock { $0 } == 1)
    }

    @Test
    func iconMissesCoalesceAreBoundedAndInvalidateOnDiscovery() async {
        let loads = Mutex(0)
        let worker = CategoryApplicationWorker(iconLimit: 2, diskDiscovery: { [] }, iconLoader: { _, _ in
            #expect(!Thread.isMainThread)
            loads.withLock { $0 += 1 }
            return nil
        })
        let first = CategoryApplicationWorker.IconRequest(bundleId: "test.one", appName: "One")
        let second = CategoryApplicationWorker.IconRequest(bundleId: "test.two", appName: "Two")
        let third = CategoryApplicationWorker.IconRequest(bundleId: "test.three", appName: "Three")
        async let a = worker.icon(for: first)
        async let b = worker.icon(for: first)
        let images = await (a, b)
        #expect(images.0 == nil && images.1 == nil)
        #expect(loads.withLock { $0 } == 1)
        _ = await worker.icon(for: second)
        _ = await worker.icon(for: first) // Touch One; Two should be evicted next.
        _ = await worker.icon(for: third)
        _ = await worker.icon(for: first)
        #expect(loads.withLock { $0 } == 3)
        _ = await worker.icon(for: second)
        #expect(loads.withLock { $0 } == 4)
        _ = await worker.discover(rules: [], forceRefresh: true)
        _ = await worker.icon(for: second)
        #expect(loads.withLock { $0 } == 5)
    }

    @Test
    func cancelledIconRequestSkipsQueuedWork() async {
        let loads = Mutex(0)
        let worker = CategoryApplicationWorker(iconLoader: { _, _ in
            loads.withLock { $0 += 1 }
            return nil
        })
        let task = Task { await worker.icon(for: .init(bundleId: "test.cancelled", appName: "Cancelled")) }
        task.cancel()
        #expect(await task.value == nil)
        #expect(loads.withLock { $0 } == 0)
    }

    @Test
    func realApplicationIconIsRasterizedToBoundedThumbnail() async {
        let worker = CategoryApplicationWorker()
        let request = CategoryApplicationWorker.IconRequest(
            bundleId: Bundle.main.bundleIdentifier ?? "", appName: "Kaskas", path: Bundle.main.bundleURL.path
        )
        let image = await worker.icon(for: request)
        #expect(image?.width == 64)
        #expect(image?.height == 64)
        let cached = await worker.icon(for: request)
        #expect(image === cached)
    }

    @Test
    func groupingPreservesOrderAndMatchesNameOrIdentifier() {
        let rules = [
            CategoryRule(appIdentifier: "test.alpha", displayName: "Alpha", categoryId: "coding"),
            CategoryRule(appIdentifier: "test.beta", displayName: "Beta", categoryId: "coding"),
            CategoryRule(appIdentifier: "test.gamma", displayName: "Gamma", categoryId: "design")
        ]
        let all = CategoryRuleGrouping(rules: rules, searchText: "  ")
        #expect(all.count == 3)
        #expect(all.groups["coding"] == Array(rules.prefix(2)))
        let filtered = CategoryRuleGrouping(rules: rules, searchText: " TEST.GAMMA ")
        #expect(filtered.count == 1)
        #expect(filtered.groups["design"] == [rules[2]])
        #expect(CategoryRuleGrouping(rules: rules, searchText: "ALPHA").groups["coding"] == [rules[0]])
    }
}
