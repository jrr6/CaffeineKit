import XCTest
@testable import CaffeineKit

final class CaffeineKitTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(CaffeineKit().text, "Hello, World!")
    }


    static var allTests = [
        ("testExample", testExample),
    ]
}
