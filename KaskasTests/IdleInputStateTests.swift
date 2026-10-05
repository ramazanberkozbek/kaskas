import Foundation
import Testing
@testable import Kaskas

struct IdleInputStateTests {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000_000)

    @Test
    func unchangedInputCountDoesNotReportReturnDespiteTimestampDrift() {
        var state = IdleInputState(monitoringSince: start)
        let idleAt = start.addingTimeInterval(180)

        #expect(state.sample(at: idleAt, threshold: 180, secondsSinceInput: 180, eventCount: 42) == .idle(start))
        #expect(state.sample(at: idleAt.addingTimeInterval(1), threshold: 180, secondsSinceInput: 180.999, eventCount: 42) == nil)
        #expect(state.sample(at: idleAt.addingTimeInterval(60), threshold: 180, secondsSinceInput: 239.999, eventCount: 42) == nil)
    }

    @Test
    func newHardwareInputReportsReturnOnce() {
        var state = IdleInputState(monitoringSince: start)
        let idleAt = start.addingTimeInterval(180)
        let returnedAt = idleAt.addingTimeInterval(7 * 60)

        #expect(state.sample(at: idleAt, threshold: 180, secondsSinceInput: 180, eventCount: 42) == .idle(start))
        #expect(state.sample(at: returnedAt, threshold: 180, secondsSinceInput: 0.2, eventCount: 43) == .returned(start, returnedAt))
        #expect(state.sample(at: returnedAt.addingTimeInterval(1), threshold: 180, secondsSinceInput: 1.2, eventCount: 43) == nil)
    }

    @Test
    func keyboardActivityPreventsIdleEvenWithoutPointerMovement() {
        var state = IdleInputState(monitoringSince: start)
        let now = start.addingTimeInterval(10 * 60)

        #expect(state.sample(at: now, threshold: 180, secondsSinceInput: 2, eventCount: 50) == nil)
        #expect(state.idleStartedAt == nil)
    }

    @Test
    func hardwareActivityRequiresNewInputAfterBaseline() {
        var state = HardwareInputState(eventCount: 42)
        let unchanged = state.sample(eventCount: 42)
        let changed = state.sample(eventCount: 43)
        let repeated = state.sample(eventCount: 43)
        #expect(!unchanged)
        #expect(changed)
        #expect(!repeated)
        // Reset at break completion discards all input from within the break.
        state = HardwareInputState(eventCount: 50)
        let oldInput = state.sample(eventCount: 50)
        let newInput = state.sample(eventCount: 51)
        #expect(!oldInput)
        #expect(newInput)
        state = HardwareInputState(eventCount: UInt32.max)
        let wrapped = state.sample(eventCount: 0)
        #expect(wrapped)
    }

}
