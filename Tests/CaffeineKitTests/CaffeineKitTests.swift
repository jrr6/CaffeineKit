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
    
    // MARK: - Utilities
    
    var cafProcExists: Bool {
        get {
            let proc = Process("/usr/bin/killall", "-0", "caffeinate")
            proc.runSynchronously()
            return proc.terminationStatus == 0
        }
    }
    
    // Workaround for Swift (?) bug
    func execute(_ closure: () -> Void) {
        closure()
    }
    
    // MARK: - Tests
    
    func testCaffeinateProcessSpawnsAndDies() {
        let caf = Caffeination()
        XCTAssert(!caf.isActive)
        try! caf.start()
        XCTAssert(caf.isActive)
        XCTAssert(cafProcExists)
        caf.stop()
        XCTAssert(!cafProcExists)
        XCTAssert(!caf.isActive)
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
        XCTAssert(!cafProcExists)
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
            XCTAssert(!self.cafProcExists)
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
        XCTAssert(cafProcExists)
        XCTAssert(caf.isActive)
        wait(for: [exp1], timeout: 2.5)
        XCTAssert(!cafProcExists)
        XCTAssert(!caf.isActive)
        caf.stop()
        caf.opts[2] = .timed(1)
        let exp2 = expectation(description: "Caffeination 2 finished")
        caf.terminationHandler = { caffeination in
            exp2.fulfill()
        }
        try! caf.start()
        XCTAssert(cafProcExists)
        XCTAssert(caf.isActive)
        wait(for: [exp2], timeout: 1.5)
        XCTAssert(!cafProcExists)
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
        XCTAssert(cafProcExists)
        XCTAssert(caf.isActive)
        caf.stop()
        XCTAssert(!cafProcExists)
        XCTAssert(!caf.isActive)
    }
    
    func testClosureLifeCycle() {
        XCTAssert(!cafProcExists)
        let closure = try! Caffeination.closure { () -> Void in
            XCTAssert(self.cafProcExists)
        }
        execute(closure)
        XCTAssert(!cafProcExists)
    }
    
    func testClosureIgnoresTimed() {
        let closure = try! Caffeination.closure(withOpts: [.idle, .display, .timed(5)]) {
            XCTAssert(self.cafProcExists)
        }
        execute(closure)
        XCTAssert(!cafProcExists)
    }
    
    func testClosureIgnoresProc() {
        let proc = Process("/bin/cat")
        try! proc.run()
        let closure = try! Caffeination.closure(withOpts: [.idle, .display, .process(proc.processIdentifier)]) {
            XCTAssert(self.cafProcExists)
        }
        execute(closure)
        XCTAssert(!cafProcExists)
        proc.terminate()
    }
}
