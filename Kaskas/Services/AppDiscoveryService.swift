import AppKit
import CoreServices
import Foundation

enum AppDiscoveryService: Sendable {
    nonisolated static func performDiskDiscovery() -> [CategoryRegistry.DiscoveredApp] {
        var map: [String: CategoryRegistry.DiscoveredApp] = [:]

        func mergeApp(_ app: CategoryRegistry.DiscoveredApp) {
            let key = app.bundleId.lowercased()
            if let existing = map[key] {
                if pathPriority(app.path) > pathPriority(existing.path) {
                    map[key] = app
                }
            } else {
                map[key] = app
            }
        }

        // 1. Layer 1: Spotlight metadata query (Instant system-wide index)
        let queryString = "kMDItemContentTypeTree == \"com.apple.application\"" as CFString
        if let query = MDQueryCreate(kCFAllocatorDefault, queryString, nil, nil) {
            MDQueryExecute(query, CFOptionFlags(kMDQuerySynchronous.rawValue))
            let count = MDQueryGetResultCount(query)
            for i in 0..<count {
                guard let rawResult = MDQueryGetResultAtIndex(query, i) else { continue }
                let mdItem = unsafeBitCast(rawResult, to: MDItem.self)
                guard let path = MDItemCopyAttribute(mdItem, kMDItemPath) as? String else { continue }
                if let app = parseDiscoveredApp(at: path) {
                    mergeApp(app)
                }
            }
        }

        // 2. Layer 2: Controlled Directory Scanning (Fallback & nested folders)
        let fm = FileManager.default
        let scanRoots = [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            NSHomeDirectory() + "/Applications",
            "/Users/Shared",
            "/System/Library/CoreServices/Applications"
        ]

        for root in scanRoots {
            guard let items = try? fm.contentsOfDirectory(atPath: root) else { continue }
            for item in items {
                guard !item.hasPrefix(".") else { continue }
                let fullPath = (root as NSString).appendingPathComponent(item)
                if item.hasSuffix(".app") {
                    if let app = parseDiscoveredApp(at: fullPath) {
                        mergeApp(app)
                    }
                } else {
                    // Check subfolders 1 level deep (e.g. Python 3.13, Glaze, Setapp, Adobe)
                    var isDir: ObjCBool = false
                    if fm.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue {
                        if let subItems = try? fm.contentsOfDirectory(atPath: fullPath) {
                            for subItem in subItems where subItem.hasSuffix(".app") {
                                let subPath = (fullPath as NSString).appendingPathComponent(subItem)
                                if let app = parseDiscoveredApp(at: subPath) {
                                    mergeApp(app)
                                }
                            }
                        }
                    }
                }
            }
        }

        if let finderApp = parseDiscoveredApp(at: "/System/Library/CoreServices/Finder.app") {
            mergeApp(finderApp)
        }

        return Array(map.values)
    }

    nonisolated static func isAllowedAppPath(_ path: String) -> Bool {
        let home = NSHomeDirectory()
        // Ignore hidden paths, trash
        if path.contains("/.") || path.contains("/.Trash/") { return false }

        // Ignore internal libraries and frameworks
        if path.hasPrefix("\(home)/Library/") ||
            path.hasPrefix("/Library/Apple/") ||
            path.hasPrefix("/Library/Frameworks/") ||
            path.hasPrefix("/Library/PrivateFrameworks/") ||
            path.hasPrefix("/Library/Image Capture/") ||
            path.hasPrefix("/Library/Application Support/") {
            return false
        }

        // System Library: Only Finder and CoreServices/Applications
        if path.hasPrefix("/System/Library/") {
            if path == "/System/Library/CoreServices/Finder.app" ||
                path.hasPrefix("/System/Library/CoreServices/Applications/") {
                return true
            }
            return false
        }

        // Build & Package manager artifacts
        if path.contains("/DerivedData/") ||
            path.contains("/Debug-") ||
            path.contains("/Release-") ||
            path.contains("/build/") ||
            path.contains("/node_modules/") ||
            path.contains("/venv/") ||
            path.contains("/.venv/") ||
            path.contains("/site-packages/") {
            return false
        }

        // Embedded app bundles (allow Xcode internal dev tools like Simulator)
        if path.contains(".app/Contents/") {
            if !path.hasPrefix("/Applications/Xcode.app/Contents/Developer/Applications") &&
                !path.hasPrefix("/Applications/Xcode.app/Contents/Applications") {
                return false
            }
        }

        return true
    }

    nonisolated private static func parseDiscoveredApp(at path: String) -> CategoryRegistry.DiscoveredApp? {
        guard isAllowedAppPath(path) else { return nil }
        guard let bundle = Bundle(path: path) else { return nil }
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? (path as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return nil }
        let bundleId = bundle.bundleIdentifier ?? cleanName
        return CategoryRegistry.DiscoveredApp(id: bundleId, name: cleanName, bundleId: bundleId, path: path)
    }

    nonisolated private static func pathPriority(_ path: String) -> Int {
        if path.hasPrefix("/Applications") { return 100 }
        if path.hasPrefix("/System/Applications") { return 90 }
        let homeApps = NSHomeDirectory() + "/Applications"
        if path.hasPrefix(homeApps) { return 80 }
        if path.hasPrefix("/System/Library") { return 70 }
        if path.hasPrefix("/Users/Shared") { return 60 }
        return 10
    }
}
