//
//  Caffeination.swift
//  CaffeineKit
//
//  Created by aaplmath on 8/14/18.
//


import Cocoa

/// A **reusable** instance of a sleep-prevention session
class Caffeination {
    enum Opt {
        /// Prevents disk idle sleep
        case disk
        
        /// Prevents display sleep
        case display
        
        /// Prevents system idle sleep
        case idle
        
        /**
         Prevents system sleep
         - Note: On MacBooks, will only work when connected to AC power.
        */
        case system
        
        /** Simulates user activity to keep display awake
         - Note: `caffeinate` should automatically timeout after 5 seconds if `.timed` is not also selected. However, due to a bug in the `caffeinate` tool, this does not currently happen, and the process will continue indefinitely.
        */
        case user
        
        /// Terminates Caffeination when process with specified PID exits. Might be preempted by .timed
        case process(Int32)
        
        /// Terminates Caffeination after specified period of time *in seconds*. Might be preempted by .process
        case timed(Double)
    }
    
    /// The expected location of the `caffeinate` executable
    public static let caffeinatePath = URL(fileURLWithPath: "/usr/bin/caffeinate")
    
    /// Indicates whether the `caffeinate` executable is in the correct location
    public static var caffeinateExists: Bool {
        get {
            return FileManager.default.fileExists(atPath: caffeinatePath.path)
        }
    }
    
    /// Responsible for trapping signals and intercepting Apple Events
    private var trapper: SignalTrapper?
    
    /// The raw `caffeinate` process, if one exists
    private var proc: Process?
    
    /// If `true`, will automatically set the `caffeinate` process to terminate with this application's termination. Has no bearing on traps
    var safetyEnabled = true
    
    /// The function to be executed once the Caffeination terminates
    var terminationHandler: ((Caffeination) -> Void)?
    
    /// The options for the Caffeination
    var opts: [Opt] = [] {
        didSet {
            if isActive {
                Logger.log(.warning, "Options were changed for a Caffeination that is already ongoing. These changes will not take effect until the Caffeination is restarted.")
            }
        }
    }
    
    /// Whether a Caffeination is currently ongoing
    var isActive: Bool {
        get {
            guard let proc = proc else {
                return false
            }
            return proc.isRunning
        }
    }
    
    /// Whether the Caffeination will be automatically terminated when the app is quit using the "Quit" menu or other Apple Event-based means
    var interceptAppTermination: Bool {
        get {
            return trapper?.interceptingNotification ?? false
        }
        set(val) {
            if val {
                if trapper == nil {
                    trapper = SignalTrapper(withHandler: defaultSignalHandler)
                }
                trapper?.registerNotificationObserver(withSelector: #selector(stop))
            } else {
                trapper?.deregisterNotificationObserver()
            }
        }
    }
    
    /**
     Initializes a new Caffeination.
     - Parameters:
        - opts: The options with which to start the Caffeintaion.
        - safely: Whether to enable safety measures to ensure that no "zombie" `caffeinate` processes can outlive the current application. Set to `true` by default, which is recommended
        - terminationHandler: A handler that will be called when the Caffeination stops. Will be set to `nil` if the parameter is not specified
     */
    init(withOpts opts: [Opt] = [.idle, .display], safely: Bool = true, terminationHandler: ((Caffeination) -> Void)? = nil) {
        self.opts = opts
        if safely {
            trapper = SignalTrapper(withHandler: defaultSignalHandler)
            try! addTrap(for: SIGABRT, SIGHUP, SIGINT, SIGQUIT, SIGTERM) // Cannot throw because no traps can possibly have been added yet
            self.interceptAppTermination = true
        } else {
            safetyEnabled = false
        }
        if let terminationHandler = terminationHandler {
            self.terminationHandler = terminationHandler
        }
    }
    
    /**
     Generates a closure that Caffeinates for the duration of its execution. Only the .disk, .display, .idle, and .user parameters will be honored.
     - Parameter closureExp: The closure during which to Caffeinate.
     - Throws: `CaffeinationError.alreadyActive` if a Caffeination is already active.
    */
    func closure<Param, Ret>(_ closureExp: @escaping (Param) -> Ret) throws -> (Param) -> Ret {
        try preCaffeinateSafetyCheck()
        return { (param: Param) -> Ret in
            try! self.start()
            let ret = closureExp(param)
            self.stop()
            return ret
        }
    }
    
    /**
     Generates a Caffienated closure not associated with any Caffeination instance. Only the .disk, .display, .idle, and .user parameters will be honored.
     - Throws: `CaffeinationError.caffeinateNotFound` if the `caffeinate` executable does not exist
     */
    static func closure<Param, Ret>(_ opts: [Opt] = [.idle, .display], closureExp: @escaping (Param) -> Ret) throws -> (Param) -> Ret {
        guard caffeinateExists else {
            throw CaffeinationError.caffeinateNotFound
        }
        let proc = Process.caffeinate(opts: opts, allowingFinite: false, safetyCheck: true)
        if #available(macOS 10.13, *) {
            try proc.run()
        } else {
            proc.launch()
        }
        return { (param: Param) -> Ret in
            let ret = closureExp(param)
            proc.terminate()
            return ret
        }
    }
    
    /**
     Generates a Caffienated closure not associated with any Caffeination instance. Only the .disk, .display, .idle, and .user parameters will be honored. Prioritizes the return of a closure and will allow the closure to run even if the `caffeinate` executable is not found. Manually use `Caffeination.caffeinateExists` to check that the intended behavior will occur.
    */
    static func unsafeClosure<Param, Ret>(_ opts: [Opt] = [.idle, .display], closureExp: @escaping (Param) -> Ret) -> (Param) -> Ret {
        var proc: Process?
        if caffeinateExists {
            proc = Process.caffeinate(opts: opts, allowingFinite: false, safetyCheck: true)
            if #available(macOS 10.13, *) {
                do {
                    try proc!.run()
                } catch {
                    Logger.log(.warning, "Unsafe closure process failed to launch—failing silently…")
                }
            } else {
                proc!.launch()
            }
        }
        return { (param: Param) -> Ret in
            let ret = closureExp(param)
            proc?.terminate()
            return ret
        }
    }
    
    /**
     Starts preventing cleanup.
     - Throws: `CaffeinationError.alreadyActive` if a Caffeination is already active, `CaffeinationError.caffeinateNotFound` if the user does not have the caffeinate binary at the expected location, or any error generated by `Process.run()` on macOS 10.13 or higher
    */
    func start() throws {
        try preCaffeinateSafetyCheck()
        proc = Process.caffeinate(opts: opts, allowingFinite: true, safetyCheck: safetyEnabled)
        proc?.terminationHandler = procDidTerminate
        
        if #available(macOS 10.13, *) {
            do {
                try proc?.run()
            } catch let err {
                throw err
            }
        } else {
            // TODO: Obj-C catching
            proc?.launch()
        }
    }
    
    /// Stops the Caffeination if it is active
    @objc func stop() {
        if isActive {
            proc?.terminate()
            proc?.waitUntilExit()
        }
    }
    
    
    /**
     Adds a trap to intercept signals. Useful for ensuring that the `caffeinate` process is terminated prior to app termination.
     - Parameter signals: Any number of system signals to trap (e.g., SIGHUP, SIGINT).
     - Throws: `SignalError.duplicateSignalAdded` if an attempt is made to trap a signal that is already being trapped.
    */
    func addTrap(for signals: Int32...) throws {
        for signal in signals {
            try trapper?.addSignal(signal)
        }
    }
    
    /**
     Sets the verbosity level of logging.
     - Parameter level: A `LogLevel` specifying the types of logs to receive. Levels are cumulative (i.e., setting the log level to `.info` will also print warnings and errors). Pass `.none` to disable logging
    */
    static func setLogLevel(_ level: LogLevel) {
        Logger.logLevel = level
    }
    
    /// Ensures that the Caffeinate executable exists and that no Caffeination is already active
    private func preCaffeinateSafetyCheck() throws {
        guard isActive == false else {
            throw CaffeinationError.alreadyActive
        }
        guard Caffeination.caffeinateExists else {
            throw CaffeinationError.caffeinateNotFound
        }
    }
    
    private func defaultSignalHandler() {
        stop()
        NSApplication.shared.terminate(self)
    }
    
    // Allows the termination handler to be mutated even after the process has started
    private func procDidTerminate(proc: Process) {
        terminationHandler?(self)
    }
    
}
