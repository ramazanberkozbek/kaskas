import AppKit
import ImageIO
import Observation

@MainActor
@Observable
final class DesktopWallpaperPreview {
    static let shared = DesktopWallpaperPreview()

    private(set) var image: NSImage?
    @ObservationIgnored private var loading: Task<CGImage?, Never>?

    func load() async {
        guard image == nil else { return }
        if loading == nil {
            // Share one decode across visits, including a visit cancelled while
            // the thumbnail is loading. ImageIO work must not block navigation.
            loading = Task.detached(priority: .utility) {
                PerformanceTrace.measure("Notification wallpaper thumbnail") {
                    let url = URL(fileURLWithPath: "/System/Library/CoreServices/DefaultDesktop.heic")
                    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
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
