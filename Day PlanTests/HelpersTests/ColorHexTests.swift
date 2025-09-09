import SwiftUI
import XCTest

@testable import Day_Plan

final class ColorHexTests: XCTestCase {
    func testRoundTrip_fromHexToColorToHex() {
        let hex = "#112233"
        let c = Color(hex: hex)
        XCTAssertNotNil(c)
        XCTAssertEqual(c?.toHexRGB(), hex)
    }

    func testInvalidHex_returnsNil() {
        XCTAssertNil(Color(hex: "#XYZXYZ"))
        XCTAssertNil(Color(hex: "#1234"))
        XCTAssertNil(Color(hex: ""))
    }
}
