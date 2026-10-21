import Testing
@testable import Kaskas

struct TamgaTests {
    @Test(arguments: [
        (0, [0, 0, 0, 0], [Int]()),
        (20, [4, 1, 0, 0], [4]),
        (15, [15, 0, 0, 0], [8, 4, 2, 1]),
        (65_535, [15, 15, 15, 15], [8, 4, 2, 1])
    ])
    func decomposition(value: Int, places: [UInt8], active0: [Int]) {
        let t = TamgaModel(value: value)
        #expect([t.place0, t.place1, t.place2, t.place3] == places)
        #expect(t.activeOz(forPlace: 0) == active0)
    }

    @Test func clamping() {
        #expect(TamgaModel(value: -10).value == 0)
        #expect(TamgaModel(value: 100_000).value == 65_535)
    }
}
