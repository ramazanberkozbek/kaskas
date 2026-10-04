import AppKit
import Foundation

/// Serial executor for Launch Services, disk discovery, and icon rasterization.
/// Only value snapshots and immutable, decoded CGImages cross to MainActor.
actor CategoryApplicationWorker {
    nonisolated struct InstallationSnapshot: Sendable {
        let apps: [CategoryRegistry.DiscoveredApp]
        let installed: [String: Bool]
    }

    nonisolated struct IconRequest: Hashable, Sendable {
        let bundleId: String
        let appName: String
        var path: String? = nil
    }

    private enum IconResult {
        case missing
        case image(CGImage)
    }

    private var snapshot: InstallationSnapshot?
    private var icons: [IconRequest: IconResult] = [:]
    private var iconOrder: [IconRequest] = []
    private let iconLimit: Int
    private let diskDiscovery: @Sendable () -> [CategoryRegistry.DiscoveredApp]
    private let applicationPath: @Sendable (String) -> String?
    private let iconLoader: @Sendable (IconRequest, [CategoryRegistry.DiscoveredApp]) -> CGImage?

    init(
        iconLimit: Int = 256,
        diskDiscovery: @escaping @Sendable () -> [CategoryRegistry.DiscoveredApp] = AppDiscoveryService.performDiskDiscovery,
        applicationPath: @escaping @Sendable (String) -> String? = { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)?.path },
        iconLoader: @escaping @Sendable (IconRequest, [CategoryRegistry.DiscoveredApp]) -> CGImage? = CategoryApplicationWorker.rasterizeIcon
    ) {
        self.iconLimit = max(1, iconLimit)
        self.diskDiscovery = diskDiscovery
        self.applicationPath = applicationPath
        self.iconLoader = iconLoader
    }

    func discover(rules: [CategoryRule], forceRefresh: Bool = false) -> InstallationSnapshot {
        if !forceRefresh, let snapshot { return snapshot }
        var apps = diskDiscovery()
        CategoryRegistry.mergeRunningApplications(into: &apps)
        apps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let identifiers = Set(apps.flatMap { [$0.bundleId.lowercased(), $0.name.lowercased()] }.filter { !$0.isEmpty })
        var installed: [String: Bool] = [:]
        for rule in rules {
            let key = rule.appIdentifier.lowercased()
            guard installed[key] == nil else { continue }
            installed[key] = identifiers.contains(key) || identifiers.contains(rule.displayName.lowercased()) ||
                (!rule.appIdentifier.isEmpty && applicationPath(rule.appIdentifier) != nil)
        }
        let result = InstallationSnapshot(apps: apps, installed: installed)
        snapshot = result
        // A new installation revision can resolve previously missing icons.
        icons.removeAll()
        iconOrder.removeAll()
        return result
    }

    func icon(for request: IconRequest) -> CGImage? {
        guard !Task.isCancelled else { return nil }
        if let cached = icons[request] {
            touch(request)
            if case .image(let image) = cached { return image }
            return nil
        }
        let image = autoreleasepool { iconLoader(request, snapshot?.apps ?? []) }
        icons[request] = image.map(IconResult.image) ?? .missing
        touch(request)
        while iconOrder.count > iconLimit {
            icons.removeValue(forKey: iconOrder.removeFirst())
        }
        return image
    }

    private func touch(_ request: IconRequest) {
        iconOrder.removeAll { $0 == request }
        iconOrder.append(request)
    }

    nonisolated private static func rasterizeIcon(_ request: IconRequest, _ apps: [CategoryRegistry.DiscoveredApp]) -> CGImage? {
        let workspace = NSWorkspace.shared
        let fm = FileManager.default
        var image: NSImage?
        if let path = request.path, !path.isEmpty, fm.fileExists(atPath: path) {
            image = workspace.icon(forFile: path)
        } else if !request.bundleId.isEmpty, let url = workspace.urlForApplication(withBundleIdentifier: request.bundleId) {
            image = workspace.icon(forFile: url.path)
        } else if let app = workspace.runningApplications.first(where: {
            $0.bundleIdentifier == request.bundleId || $0.localizedName == request.appName
        }) {
            image = app.icon
        } else {
            let searchName = request.appName.hasSuffix(".app") ? request.appName : "\(request.appName).app"
            for directory in AppDiscoveryService.standardApplicationDirectories {
                let path = (directory as NSString).appendingPathComponent(searchName)
                if fm.fileExists(atPath: path) {
                    image = workspace.icon(forFile: path)
                    break
                }
            }
            if image == nil, let app = apps.first(where: {
                (!request.bundleId.isEmpty && $0.bundleId.caseInsensitiveCompare(request.bundleId) == .orderedSame) ||
                (!request.appName.isEmpty && $0.name.caseInsensitiveCompare(request.appName) == .orderedSame)
            }), !app.path.isEmpty, fm.fileExists(atPath: app.path) {
                image = workspace.icon(forFile: app.path)
            }
        }
        guard let source = image?.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let context = CGContext(data: nil, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.interpolationQuality = .high
        context.draw(source, in: CGRect(x: 0, y: 0, width: 64, height: 64))
        return context.makeImage()
    }
}
