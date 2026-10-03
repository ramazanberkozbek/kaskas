import Foundation

/// System-level actions and integrations.
enum SystemAction {
    /// Locks the macOS screen immediately.
    ///
    /// - Note: This function dynamically loads `SACLockScreenImmediate` from Apple's private
    ///   `login.framework` (`/System/Library/PrivateFrameworks/login.framework/Versions/Current/login`).
    ///   This is intended for Developer ID / Notarized direct distribution outside the Mac App Store sandbox.
    ///   If sandboxed or if the framework symbol is unavailable, it gracefully fails without crashing.
    static func lockScreen() {
        let lib = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_LAZY)
        guard let lib else { return }
        defer { dlclose(lib) }

        guard let sym = dlsym(lib, "SACLockScreenImmediate") else { return }
        typealias LockFunction = @convention(c) () -> Int32
        let lock = unsafeBitCast(sym, to: LockFunction.self)
        _ = lock()
    }
}
