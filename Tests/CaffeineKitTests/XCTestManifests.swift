import XCTest

#if !os(macOS)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(CaffeineKitTests.allTests),
    ]
}
#endif