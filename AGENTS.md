# SwiftUI implementation

- Before using a SwiftUI API introduced in iOS 26, inspect the installed Xcode SDK's `.swiftinterface` files or compiler diagnostics, verify the exact native API, and compile a minimal reproduction before changing production code.
- Use native system behavior when an appropriate API exists instead of emulating it manually.
