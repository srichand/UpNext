import XCTest
@testable import UpNext

final class StringExtensionTests: XCTestCase {
    func testTruncatedReturnsOriginalStringWhenShorterThanLimit() {
        XCTAssertEqual("UpNext".truncated(to: 20), "UpNext")
    }

    func testTruncatedReturnsOriginalStringWhenExactlyAtLimit() {
        XCTAssertEqual("12345".truncated(to: 5), "12345")
    }

    func testTruncatedAddsEllipsisWhenOverLimit() {
        XCTAssertEqual("123456".truncated(to: 5), "1234…")
    }
}
