import Foundation

@MainActor
final class SessionScheduler {
    private var scheduledTask: Task<Void, Never>?

    func schedule(
        for deadline: Date?,
        action: @escaping @MainActor @Sendable () -> Void
    ) {
        cancel()

        guard let deadline else {
            return
        }

        let delay = max(0, deadline.timeIntervalSinceNow)
        scheduledTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }

            guard !Task.isCancelled else {
                return
            }

            action()
        }
    }

    func cancel() {
        scheduledTask?.cancel()
        scheduledTask = nil
    }
}
