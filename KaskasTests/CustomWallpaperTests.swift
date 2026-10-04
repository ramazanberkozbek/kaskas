import AppKit
import ImageIO
import Synchronization
import Testing
import UniformTypeIdentifiers
@testable import Kaskas

@MainActor
struct CustomWallpaperTests {
    @Test
    func concurrentPanelsShareDecodeAndSizesAndRevisionsStayDistinct() async throws {
        let loads = Mutex(0)
        let worker = CustomWallpaperImageWorker(decoder: { url, pixels in
            #expect(!Thread.isMainThread)
            loads.withLock { $0 += 1 }
            return CustomWallpaperImageWorker.decode(url: url, pixels: pixels)
        })
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("source.png")
        try writeImage(to: source, width: 1024, height: 512)
        let request = CustomWallpaperImageWorker.Request(path: source.path, revision: 0, pixels: 256)
        async let a = worker.image(for: request)
        async let b = worker.image(for: request)
        let (first, second) = await (a, b)
        #expect(first === second)
        #expect(first?.width == 256)
        #expect(first?.height == 128)
        #expect(loads.withLock { $0 } == 1)
        let larger = await worker.image(for: .init(path: source.path, revision: 0, pixels: 512))
        #expect(larger?.width == 512)
        let nextRevision = await worker.image(for: .init(path: source.path, revision: 1, pixels: 256))
        #expect(nextRevision !== first)
        #expect(loads.withLock { $0 } == 3)
    }

    @Test
    func replacementAtSamePathInvalidatesCachedFileRevision() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("source.png")
        let worker = CustomWallpaperImageWorker()
        let request = CustomWallpaperImageWorker.Request(path: source.path, revision: 0, pixels: 256)
        try writeImage(to: source, width: 512, height: 256)
        #expect(await worker.image(for: request)?.height == 128)
        // Rename a different inode onto the same path, just as atomic file replacement does.
        let staged = directory.appendingPathComponent("replacement.png")
        try writeImage(to: staged, width: 256, height: 512)
        _ = try FileManager.default.replaceItemAt(source, withItemAt: staged)
        #expect(await worker.image(for: request)?.width == 128)
    }

    @Test
    func cancelledRequestDoesNotDecodeOrPoisonSharedCache() async {
        let loads = Mutex(0)
        let worker = CustomWallpaperImageWorker(decoder: { _, _ in
            loads.withLock { $0 += 1 }
            return nil
        })
        let request = CustomWallpaperImageWorker.Request(path: "/absent", revision: 0, pixels: 256)
        let task = Task { await worker.image(for: request) }
        task.cancel()
        #expect(await task.value == nil)
        #expect(loads.withLock { $0 } == 0)
        _ = await worker.image(for: request)
        _ = await worker.image(for: request)
        #expect(loads.withLock { $0 } == 1)
    }

    @Test
    func cancelledConsumerLeavesCompletedDecodeAvailableForOtherPanels() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("source.png")
        try writeImage(to: source, width: 64, height: 64)
        let started = AsyncStream<Void>.makeStream()
        let release = DispatchSemaphore(value: 0)
        let loads = Mutex(0)
        let worker = CustomWallpaperImageWorker(decoder: { url, pixels in
            loads.withLock { $0 += 1 }
            started.continuation.yield(())
            release.wait()
            return CustomWallpaperImageWorker.decode(url: url, pixels: pixels)
        })
        let request = CustomWallpaperImageWorker.Request(path: source.path, revision: 0, pixels: 256)
        let task = Task { await worker.image(for: request) }
        for await _ in started.stream { break }
        task.cancel()
        release.signal()
        let decoded = await task.value
        #expect(decoded != nil)
        #expect(await worker.image(for: request) === decoded)
        #expect(loads.withLock { $0 } == 1)
    }

    @Test
    func importsPrepareThumbnailAndNeverOverwritePreviousRevision() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("source.png")
        let store = CustomWallpaperStore(directory: directory.appendingPathComponent("store"))
        try writeImage(to: source, width: 1024, height: 512)
        let first = try await store.save(from: source)
        #expect(first.thumbnail.width == 256)
        let firstBytes = try Data(contentsOf: first.url)
        try writeImage(to: source, width: 512, height: 1024)
        let second = try await store.save(from: source)
        #expect(first.url != second.url)
        #expect(try Data(contentsOf: first.url) == firstBytes)
        #expect(second.thumbnail.height == 256)
        let loads = Mutex(0)
        let worker = CustomWallpaperImageWorker(decoder: { _, _ in
            loads.withLock { $0 += 1 }
            return nil
        })
        await worker.prepareImportedThumbnail(second, revision: 2)
        #expect(await worker.image(for: .init(path: second.url.path, revision: 2, pixels: 256)) === second.thumbnail)
        #expect(loads.withLock { $0 } == 0)
        await store.removeOwnedFile(at: first.url)
        #expect(!FileManager.default.fileExists(atPath: first.url.path))
        await store.removeOwnedFile(at: source)
        #expect(FileManager.default.fileExists(atPath: source.path))
    }

    @Test
    func failedAndCancelledImportsLeaveActiveFileAndNoStagingFiles() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("source.png")
        let destination = directory.appendingPathComponent("store")
        let store = CustomWallpaperStore(directory: destination)
        try writeImage(to: source, width: 64, height: 64)
        let active = try await store.save(from: source)
        let activeBytes = try Data(contentsOf: active.url)
        try Data("invalid image".utf8).write(to: source)
        do {
            _ = try await store.save(from: source)
            Issue.record("Corrupt import succeeded")
        } catch { }
        let cancelled = Task { try await store.save(from: source) }
        cancelled.cancel()
        do {
            _ = try await cancelled.value
            Issue.record("Cancelled import succeeded")
        } catch is CancellationError { }
        #expect(try Data(contentsOf: active.url) == activeBytes)
        #expect(try FileManager.default.contentsOfDirectory(atPath: destination.path).count == 1)
    }

    @Test
    func changedSelectionRejectsImportAndKeepsSavedConfiguration() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("source.png")
        try writeImage(to: source, width: 64, height: 64)
        let started = AsyncStream<Void>.makeStream()
        let release = DispatchSemaphore(value: 0)
        let wallpaperStore = CustomWallpaperStore(directory: directory.appendingPathComponent("store"), thumbnailLoader: { url, pixels in
            #expect(!Thread.isMainThread)
            started.continuation.yield(())
            release.wait()
            return CustomWallpaperImageWorker.decode(url: url, pixels: pixels)
        })
        let suite = "WallpaperSelectionTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let sessionStore = SessionStore(defaults: defaults)
        let controller = SessionController(store: sessionStore, customWallpaperStore: wallpaperStore)
        let task = Task { try await controller.setCustomWallpaper(from: source) }
        for await _ in started.stream { break }
        var configuration = controller.configuration
        configuration.breakBackground = .custom
        configuration.customWallpaperPath = "/previous-wallpaper.png"
        controller.updateConfiguration(configuration)
        release.signal()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(controller.configuration.customWallpaperPath == "/previous-wallpaper.png")
        #expect(sessionStore.loadConfiguration().customWallpaperPath == "/previous-wallpaper.png")
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.appendingPathComponent("store").path).isEmpty)
    }

    @Test
    func newerImportWinsEvenWhenOlderCopyHasAlreadyStarted() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let firstSource = directory.appendingPathComponent("first.png")
        let secondSource = directory.appendingPathComponent("second.png")
        try writeImage(to: firstSource, width: 128, height: 64)
        try writeImage(to: secondSource, width: 64, height: 128)
        let firstStarted = AsyncStream<Void>.makeStream()
        let secondStarted = AsyncStream<Void>.makeStream()
        let release = DispatchSemaphore(value: 0)
        let loads = Mutex(0)
        let wallpaperStore = CustomWallpaperStore(directory: directory.appendingPathComponent("store"), thumbnailLoader: { url, pixels in
            let first = loads.withLock { value in value += 1; return value == 1 }
            if first {
                firstStarted.continuation.yield(())
                release.wait()
            }
            return CustomWallpaperImageWorker.decode(url: url, pixels: pixels)
        })
        let suite = "WallpaperOrderingTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let sessionStore = SessionStore(defaults: defaults)
        let controller = SessionController(store: sessionStore, customWallpaperStore: wallpaperStore)
        let first = Task { try await controller.setCustomWallpaper(from: firstSource) }
        for await _ in firstStarted.stream { break }
        let second = Task {
            secondStarted.continuation.yield(())
            try await controller.setCustomWallpaper(from: secondSource)
        }
        for await _ in secondStarted.stream { break }
        release.signal()
        try await second.value
        await #expect(throws: CancellationError.self) { try await first.value }
        let path = try #require(controller.configuration.customWallpaperPath)
        #expect(try Data(contentsOf: URL(fileURLWithPath: path)) == Data(contentsOf: secondSource))
        #expect(sessionStore.loadConfiguration().customWallpaperPath == path)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.appendingPathComponent("store").path).count == 1)
    }

    @Test
    func nextProcessPrunesObsoleteFilesButPreservesActiveAndSelectedSource() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("source.png")
        try writeImage(to: source, width: 64, height: 64)
        let destination = directory.appendingPathComponent("store")
        let firstProcess = CustomWallpaperStore(directory: destination)
        let retired = try await firstProcess.save(from: source)
        let active = try await firstProcess.save(from: source)
        let selected = try await firstProcess.save(from: source)
        let nextProcess = CustomWallpaperStore(directory: destination)
        _ = try await nextProcess.save(from: selected.url, preservingPath: active.url.path)
        #expect(!FileManager.default.fileExists(atPath: retired.url.path))
        #expect(FileManager.default.fileExists(atPath: active.url.path))
        #expect(FileManager.default.fileExists(atPath: selected.url.path))
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("wallpaper-test-\(UUID())")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func writeImage(to url: URL, width: Int, height: Int) throws {
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 0.3, green: 0.5, blue: 0.7, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
    }
}
