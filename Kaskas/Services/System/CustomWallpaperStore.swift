import Darwin
import Foundation

/// Stages the image beside its destination before atomically replacing the previous file.
struct CustomWallpaperStore {
    let directory: URL

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0].appendingPathComponent(Bundle.main.bundleIdentifier ?? "Kaskas", isDirectory: true)
    }

    func save(from sourceURL: URL) throws -> URL {
        let hasAccess = sourceURL.startAccessingSecurityScopedResource()
        defer { if hasAccess { sourceURL.stopAccessingSecurityScopedResource() } }

        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent("custom_wallpaper.\(sourceURL.pathExtension)")
        let staged = directory.appendingPathComponent(".wallpaper-\(UUID().uuidString)")
        defer { try? manager.removeItem(at: staged) }
        try manager.copyItem(at: sourceURL, to: staged)
        guard rename(staged.path, destination.path) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        return destination
    }
}
