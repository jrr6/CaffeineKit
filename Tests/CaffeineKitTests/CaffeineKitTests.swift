import XCTest
@testable import CaffeineKit

@available(macOS 10.13, *)
extension Process {
    convenience init(_ executablePath: String, _ arguments: String...) {
        self.init()
        self.launchPath = executablePath
        self.arguments = arguments
        self.standardOutput = FileHandle.nullDevice
        self.standardError = FileHandle.nullDevice
    }
    func runSynchronously() {
        try! self.run()
        self.waitUntilExit()
    }
}

@available(macOS 10.13, *)
final class CaffeineKitTests: XCTestCase {
    
    var caffeinateExists: Bool {
        get {
            let proc = Process("/usr/bin/killall", "-0", "caffeinate")
            proc.runSynchronously()
            return proc.terminationStatus == 0
        }
    }
    
    func testCaffeinateProcessSpawnsAndDies() {
        let caf = Caffeination(withOpts: [.idle, .display])
        XCTAssert(!caf.isActive)
        try! caf.start()
        XCTAssert(caf.isActive)
        XCTAssert(caffeinateExists)
        caf.stop()
        let proc2 = Process("/usr/bin/killall", "-0", "caffeinate")
        proc2.runSynchronously()
        XCTAssert(!caffeinateExists)
    }
    
    func testApproximateTimedAccuracy() {
        let expectation = self.expectation(description: "Caffeination finished")
        let caf = Caffeination(withOpts: [.idle, .display, .timed(2)]) { process in
            expectation.fulfill()
        }
        try! caf.start()
        wait(for: [expectation], timeout: 2.5)
        caf.stop()
    }
    
    func testProcess() {
        let proc = Process("/bin/cat")
        try! proc.run()
        let caf = Caffeination(withOpts: [.idle, .display, .process(proc.processIdentifier)])
        try! caf.start()
        Thread.sleep(forTimeInterval: 2)
        proc.terminate()
        Thread.sleep(forTimeInterval: 0.1)
        XCTAssert(!caffeinateExists)
        XCTAssert(!caf.isActive)
    }


    static var allTests = [
        ("testCaffeinateProcessSpawnsAndDies", testCaffeinateProcessSpawnsAndDies),
        ("testApproximateTimedAccuracy", testApproximateTimedAccuracy),
        ("testProcess", testProcess)
    ]
}
