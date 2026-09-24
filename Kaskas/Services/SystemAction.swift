import Foundation

enum SystemAction {
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
