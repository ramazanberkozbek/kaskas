import AppKit
import ImageIO
import Observation

@MainActor
@Observable
final class DesktopWallpaperPreview {
    static let shared = DesktopWallpaperPreview()
    // Generated specifically for Kaskas with the built-in imagegen tool.
    // No Apple image is bundled.
    static let protection = DesktopWallpaperPreview(
        wallpaperURL: Bundle.main.url(forResource: "ProtectionBackdrop", withExtension: "png")
    )

    private let wallpaperURL: URL?

    init(wallpaperURL: URL? = URL(fileURLWithPath: "/System/Library/CoreServices/DefaultDesktop.heic")) {
        self.wallpaperURL = wallpaperURL
    }

    private(set) var image: NSImage?
    @ObservationIgnored private var loading: Task<CGImage?, Never>?

    func load() async {
        guard image == nil, let wallpaperURL else { return }
        if loading == nil {
            // Share one decode across visits, including a visit cancelled while
            // the thumbnail is loading. ImageIO work must not block navigation.
            loading = Task.detached(priority: .utility) {
                PerformanceTrace.measure("Notification wallpaper thumbnail") {
                    guard let source = CGImageSourceCreateWithURL(wallpaperURL as CFURL, nil) else { return nil }
                    return CGImageSourceCreateThumbnailAtIndex(source, 0, [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceThumbnailMaxPixelSize: 1200,
                        kCGImageSourceShouldCacheImmediately: true
                    ] as CFDictionary)
                }
            }
        }
        if let thumbnail = await loading?.value, image == nil {
            image = NSImage(cgImage: thumbnail, size: NSSize(width: thumbnail.width, height: thumbnail.height))
        }
    }
}
