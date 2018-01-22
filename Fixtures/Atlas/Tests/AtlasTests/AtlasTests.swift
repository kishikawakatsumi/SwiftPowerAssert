import XCTest
@testable import Atlas

class AtlasTests: XCTestCase {
    func testAustria() {
        XCTAssertEqual(Country(code: "AT").emojiFlag, "\u{1f1e6}\u{1f1f9}")
    }

    func testTurkey() {
        XCTAssertEqual(Country(code: "TR").emojiFlag, "\u{1f1f9}\u{1f1f7}")
    }

    func testUnitedStates() {
        XCTAssertEqual(Country(code: "US").emojiFlag, "\u{1f1fa}\u{1f1f8}")
    }

    func testJapan() {
        XCTAssertEqual(Country(code: "JP").emojiFlag, "\u{1f1ef}\u{1f1f5}")
    }

    func testPuertoRico() {
        XCTAssertEqual(Country(code: "PR").emojiFlag, "\u{1f1f5}\u{1f1f7}")
    }
}

extension AtlasTests {
    static var allTests : [(String, (AtlasTests) -> () throws -> Void)] {
        return [
            ("testAustria", testAustria),
            ("testTurkey", testTurkey),
            ("testUnitedStates", testUnitedStates)
        ]
    }
}
