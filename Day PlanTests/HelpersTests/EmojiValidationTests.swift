import XCTest

@testable import Day_Plan

final class EmojiValidationTests: XCTestCase {
    func testExactlyOneEmoji_simple() {
        XCTAssertTrue("👍".isExactlyOneEmoji)
        XCTAssertFalse("A".isExactlyOneEmoji)
    }

    func testExactlyOneEmoji_flagAndZWJ() {
        XCTAssertTrue("🇺🇸".isExactlyOneEmoji)  // flag (2 scalars, 1 grapheme)
        XCTAssertTrue("👨‍👩‍👧‍👦".isExactlyOneEmoji)  // family ZWJ sequence
    }

    func testLastEmoji_andClamp() {
        XCTAssertEqual("Hi 👍!".lastEmoji, "👍")
        XCTAssertNil("Hello".lastEmoji)
        XCTAssertEqual("foo👋bar".clampedToSingleEmoji, "👋")
        XCTAssertEqual("nope".clampedToSingleEmoji, "")
    }
}
