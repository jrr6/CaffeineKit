import XCTest
@testable import CaffeineKit

@available(macOS 10.13, *)
extension Process {
    convenience init(_ executablePath: String, _ arguments: String...) {
        self.init()
        self.executableURL = URL(fileURLWithPath: executablePath)
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
        let caf = Caffeination()
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
        let caf = Caffeination(withOpts: [.idle, .display, .timed(2)]) { caffeination in
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
    
    func testNoErrorOnBadStopCall() {
        let caf = Caffeination()
        caf.stop()
        try! caf.start()
        caf.stop()
        caf.stop()
    }
    
    func testSimpleCaffeinationReusability() {
        let caf = Caffeination()
        try! caf.start()
        caf.stop()
        do {
            try caf.start()
        } catch {
            XCTFail("Caffeination couldn't be reused")
        }
        caf.stop()
    }
    
    func testCaffeinateEndedInTerminationHandler() {
        let caf = Caffeination() { caffeination in
            XCTAssert(!self.caffeinateExists)
        }
        try! caf.start()
        caf.stop()
    }
    
    func testChangeTerminationHandler() {
        let exp1 = expectation(description: "Handler 1")
        let exp2 = expectation(description: "Handler 2")
        let caf = Caffeination() { caffeination in
            exp1.fulfill()
        }
        try! caf.start()
        caf.stop()
        wait(for: [exp1], timeout: 1)
        caf.terminationHandler = { caffeination in
            exp2.fulfill()
        }
        try! caf.start()
        caf.stop()
        wait(for: [exp2], timeout: 1)
    }
    
    func testChangeTimedOptReusability() {
        let exp1 = expectation(description: "Caffeination 1 finished")
        let caf = Caffeination(withOpts: [.idle, .display, .timed(2)]) { caffeination in
            exp1.fulfill()
        }
        try! caf.start()
        XCTAssert(caffeinateExists)
        XCTAssert(caf.isActive)
        wait(for: [exp1], timeout: 2.5)
        XCTAssert(!caffeinateExists)
        XCTAssert(!caf.isActive)
        caf.stop()
        caf.opts[2] = .timed(1)
        let exp2 = expectation(description: "Caffeination 2 finished")
        caf.terminationHandler = { caffeination in
            exp2.fulfill()
        }
        try! caf.start()
        XCTAssert(caffeinateExists)
        XCTAssert(caf.isActive)
        wait(for: [exp2], timeout: 1.5)
        XCTAssert(!caffeinateExists)
        XCTAssert(!caf.isActive)
        caf.stop()
    }
    
    func testThrowingWhenAlreadyStarted() {
        let caf = Caffeination()
        do {
            try caf.start()
        } catch {
            XCTFail("First start didn't succeed")
        }
        do {
            try caf.start()
            XCTFail("Should have thrown")
        } catch let e as CaffeinationError {
            switch e {
            case .alreadyActive:
                break
            default:
                XCTFail("Wrong error thrown")
            }
        } catch {
            XCTFail("Wrong, non-CaffeinationError error thrown")
        }
        XCTAssert(caffeinateExists)
        XCTAssert(caf.isActive)
        caf.stop()
        XCTAssert(!caffeinateExists)
        XCTAssert(!caf.isActive)
    }
}
