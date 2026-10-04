import CoreGraphics
import Darwin
import Foundation

/// Copies and validates an immutable wallpaper revision before atomically installing it.
actor CustomWallpaperStore {
    static let shared = CustomWallpaperStore()
    nonisolated struct Imported: Sendable {
        let url: URL
        let thumbnail: CGImage
    }

    let directory: URL
    private var prunedPreviousProcessRevisions = false
    private let thumbnailLoader: @Sendable (URL, Int) -> CGImage?

    init(directory: URL? = nil,
         thumbnailLoader: @escaping @Sendable (URL, Int) -> CGImage? = CustomWallpaperImageWorker.decode) {
        self.thumbnailLoader = thumbnailLoader
        self.directory = directory ?? FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0].appendingPathComponent(Bundle.main.bundleIdentifier ?? "Kaskas", isDirectory: true)
    }

    func save(from sourceURL: URL, preservingPath: String? = nil) throws -> Imported {
        let trace = PerformanceTrace.begin("Custom wallpaper import")
        defer { PerformanceTrace.end(trace) }
        try Task.checkCancellation()
        let hasAccess = sourceURL.startAccessingSecurityScopedResource()
        defer { if hasAccess { sourceURL.stopAccessingSecurityScopedResource() } }

        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        if !prunedPreviousProcessRevisions {
            // Keep prior revisions for this process: a visible break panel may still use
            // an older configuration, and UserDefaults writes may not yet be on disk.
            // On the first import of the next process, only the saved active revision
            // (and the selected source, if reimporting it) needs to survive.
            let files = (try? manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
            let preservedURL = preservingPath.map { URL(fileURLWithPath: $0).resolvingSymlinksInPath().standardizedFileURL }
            let selectedURL = sourceURL.resolvingSymlinksInPath().standardizedFileURL
            for file in files {
                let canonicalURL = file.resolvingSymlinksInPath().standardizedFileURL
                if canonicalURL != preservedURL && canonicalURL != selectedURL
                    && file.lastPathComponent.hasPrefix("custom_wallpaper-") {
                    try? manager.removeItem(at: file)
                }
            }
            prunedPreviousProcessRevisions = true
        }
        // Unique revisions keep a superseded import from replacing the active file.
        let destination = directory.appendingPathComponent("custom_wallpaper-\(UUID().uuidString).\(sourceURL.pathExtension)")
        let staged = directory.appendingPathComponent(".wallpaper-\(UUID().uuidString)")
        defer { try? manager.removeItem(at: staged) }
        try manager.copyItem(at: sourceURL, to: staged)
        try Task.checkCancellation()
        // Validate a bounded image before activation; never fully decode the source.
        guard let thumbnail = thumbnailLoader(staged, 256) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try Task.checkCancellation()
        guard rename(staged.path, destination.path) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        return Imported(url: destination, thumbnail: thumbnail)
    }

    /// Only files owned by this store can be removed after an import is superseded.
    func removeOwnedFile(at url: URL) {
        guard url.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL == directory.resolvingSymlinksInPath().standardizedFileURL,
              url.lastPathComponent.hasPrefix("custom_wallpaper-") else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
