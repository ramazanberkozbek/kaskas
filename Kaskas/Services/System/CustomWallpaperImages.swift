import AppKit
import ImageIO
import Observation
import SwiftUI

/// Serial ImageIO executor. Only fully decoded immutable CGImages leave this actor.
actor CustomWallpaperImageWorker {
    static let shared = CustomWallpaperImageWorker()

    nonisolated struct Request: Hashable, Sendable {
        let path: String
        let revision: Int
        let pixels: Int
    }

    private struct Key: Hashable {
        let request: Request
        let modification: Date?
        let fileNumber: UInt64?
        let bytes: UInt64?
    }

    private enum Result {
        case missing
        case image(CGImage)
    }

    private var cache: [Key: Result] = [:]
    private var order: [Key] = []
    private var cachedBytes = 0
    // Retain one oversized display image so equal requests from other panels still share it.
    private let byteLimit = 128 * 1024 * 1024
    private let decoder: @Sendable (URL, Int) -> CGImage?

    init(decoder: @escaping @Sendable (URL, Int) -> CGImage? = CustomWallpaperImageWorker.decode) {
        self.decoder = decoder
    }

    private func key(for request: Request) -> Key {
        let attributes = try? FileManager.default.attributesOfItem(atPath: request.path)
        return Key(request: request, modification: attributes?[.modificationDate] as? Date,
                   fileNumber: attributes?[.systemFileNumber] as? UInt64,
                   bytes: attributes?[.size] as? UInt64)
    }

    func prepareImportedThumbnail(_ imported: CustomWallpaperStore.Imported, revision: Int) {
        let request = Request(path: imported.url.path, revision: revision, pixels: 256)
        insert(imported.thumbnail, for: key(for: request))
    }

    func image(for request: Request) -> CGImage? {
        guard !Task.isCancelled else { return nil }
        // Metadata is read on this executor, including when a file at the same path changes.
        let key = key(for: request)
        if let result = cache[key] {
            touch(key)
            if case .image(let image) = result { return image }
            return nil
        }
        let image = autoreleasepool {
            PerformanceTrace.measure("Custom wallpaper decode", detail: "pixels=\(request.pixels)") {
                decoder(URL(fileURLWithPath: request.path), request.pixels)
            }
        }
        // Once decoding has started, retain it for other panels even if its first
        // consumer disappeared. Each consumer checks cancellation before publication.
        insert(image, for: key)
        return image
    }

    private func insert(_ image: CGImage?, for key: Key) {
        if case .image(let previous) = cache[key] {
            cachedBytes -= previous.bytesPerRow * previous.height
        }
        cache[key] = image.map(Result.image) ?? .missing
        cachedBytes += image.map { $0.bytesPerRow * $0.height } ?? 0
        touch(key)
        while order.count > 12 || (cachedBytes > byteLimit && order.count > 1) {
            let oldest = order.removeFirst()
            if case .image(let removed) = cache.removeValue(forKey: oldest) {
                cachedBytes -= removed.bytesPerRow * removed.height
            }
        }
    }

    private func touch(_ key: Key) {
        order.removeAll { $0 == key }
        order.append(key)
    }

    nonisolated static func decode(url: URL, pixels: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [
            kCGImageSourceShouldCache: false
        ] as CFDictionary) else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, pixels),
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary)
    }
}

/// Invalidates live consumers even when an import replaces the same path.
@MainActor
@Observable
final class CustomWallpaperImages {
    static let shared = CustomWallpaperImages()
    private(set) var revision = 0

    func didImport() { revision += 1 }
}

/// View-local publication and SwiftUI task cancellation prevent stale navigation/size results.
/// The shared worker coalesces requests from multiple display panels and settings previews.
struct PreparedCustomWallpaperImage: View {
    let path: String
    @Environment(\.displayScale) private var displayScale
    @State private var images = CustomWallpaperImages.shared
    @State private var loadedRequest: CustomWallpaperImageWorker.Request?
    @State private var image: NSImage?

    var body: some View {
        GeometryReader { geometry in
            let request = CustomWallpaperImageWorker.Request(
                path: path, revision: images.revision,
                // Bucket resize requests to avoid decoding for every point of window resizing.
                pixels: max(256, Int(ceil(max(geometry.size.width, geometry.size.height) * displayScale / 256)) * 256)
            )
            ZStack {
                if loadedRequest == request, let image {
                    Image(nsImage: image).resizable().scaledToFill()
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .task(id: request) {
                let decoded = await CustomWallpaperImageWorker.shared.image(for: request)
                guard !Task.isCancelled else { return }
                image = decoded.map { NSImage(cgImage: $0, size: NSSize(width: $0.width, height: $0.height)) }
                loadedRequest = request
            }
        }
    }
}
