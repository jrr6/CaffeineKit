//
//  Caffeination.swift
//  CaffeineKit
//
//  Created by aaplmath on 8/14/18.
//


import Cocoa

/// An instance of a sleep-prevention session.
public class Caffeination {
    
    /// An customization option for a `Caffeination`.
    public enum Opt {
        /// Prevents disk idle sleep.
        case disk
        
        /// Prevents display sleep.
        case display
        
        /// Prevents system idle sleep.
        case idle
        
        /**
         Prevents system sleep.
         - Note: On MacBooks, will only work when connected to AC power.
        */
        case system
        
        /**
         Simulates user activity to keep display awake.
         - Note: `caffeinate` should automatically timeout after 5 seconds if `.timed` is not also selected. However, due to a bug in the `caffeinate` tool, this does not currently happen, and the process will continue indefinitely.
        */
        case user
        
        /// Terminates Caffeination when process with specified PID exits. Might be preempted by `.timed`.
        case process(Int32)
        
        /// Terminates Caffeination after specified period of time *in seconds*. Might be preempted by `.process`.
        case timed(TimeInterval)
        
        /// The default options for a standard Caffeination.
        public static var defaults: [Opt] {
            get {
                return [.idle, .display]
            }
        }
        
        /// Converts an Opt to the raw argument(s) passed to caffeinate.
        public var argumentList: [String] {
            get {
                switch self {
                case .disk:
                    return ["-m"]
                case .display:
                    return ["-d"]
                case .idle:
                    return ["-i"]
                case .system:
                    return ["-s"]
                case .user:
                    return ["-u"]
                case let .timed(seconds):
                    return ["-t", String(seconds)]
                case let .process(pid):
                    return ["-w", String(pid)]
                }
            }
        }
        
        /**
         Returns an `Opt` corresponding to a single caffeinate argument string.
         - Parameter string: The String containing the argument to parse.
         - Returns: An `Opt` corresponding to the argument passed, or `nil` if the argument was not recognized.
         - Note: Options that require a numerical argument (e.g., `-t`) should use `from(_ array:)`.
         */
        public static func from(_ string: String) -> Opt? {
            switch (string) {
            case "-m":
                return .disk
            case "-d":
                return .display
            case "-i":
                return .idle
            case "-s":
                return .system
            case "-u":
                return .user
            default:
                return nil
            }
        }
        
        /**
         Returns an `Opt` from a [String] containing a **single** argument to caffeinate and, if necessary, an associated numerical argument.
         - Parameter array: The array containing the **single** argument to caffeinate and an associated value (if necessary).
         - Returns: An `Opt` corresponding to the argument, or `nil`.
         - Note: `nil` will be returned if:
            - an unknown argument is passed (e.g., `["-f"]`).
            - a value is passed for an argument that doesn't accept one (e.g., `["-m", "42"]`).
            - no value is passed for an argument that requires one (e.g., `["-w"]`).
            - multiple option arguments are passed (e.g., `["-d", "-m"]`) (use `array(from:)` instead).
        */
        public static func from(_ array: [String]) -> Opt? {
            if array.count == 1 {
                return Opt.from(array[0])
            } else if array.count == 2 {
                switch array[0] {
                case "-t":
                    guard let time = TimeInterval(array[1]) else {
                        return nil
                    }
                    return .timed(time)
                case "-w":
                    guard let proc = Int32(array[1]) else {
                        return nil
                    }
                    return .process(proc)
                default:
                    return nil
                }
            }
            return nil
        }
        
        /**
         Returns an [Opt] from a [String] containing raw arguments (and their associated integer values, if needed) to caffeinate, or `nil` if an invalid value is passed (see discussion).
         - Parameter stringArray: The array from which to parse the argument (and associated value).
         - Returns: An array of `Opt`s corresponding to the values passed, or `nil`.
         - Note: `nil` will be returned if:
            - an unknown argument is passed (e.g., `["-f"]`).
            - a value is passed for an argument that doesn't accept one (e.g., `["-m", "42"]`).
            - no value is passed for an argument that requires one (e.g., `["-w", "-d"]`).
         */
        public static func array(from stringArray: [String]) -> [Opt]? {
            var res: [Opt] = []
            var i = 0
            while i < stringArray.count {
                // While this switch is redundant, the performance loss caused by making calls to `from` is significant enough that it is worth the trade-off
                switch stringArray[i] {
                case "-m":
                    res.append(.disk)
                case "-d":
                    res.append(.display)
                case "-i":
                    res.append(.idle)
                case "-s":
                    res.append(.system)
                case "-u":
                    res.append(.user)
                case "-t":
                    guard let time = TimeInterval(stringArray[i + 1]) else {
                        return nil
                    }
                    res.append(.timed(time))
                    i += 1
                case "-w":
                    guard let proc = Int32(stringArray[i + 1]) else {
                        return nil
                    }
                    res.append(.process(proc))
                    i += 1
                default:
                    return nil
                }
                i += 1
            }
            return res
        }
    }
    
    /// The expected location of the `caffeinate` executable.
    public static let caffeinatePath = URL(fileURLWithPath: "/usr/bin/caffeinate")
    
    /// Indicates whether the `caffeinate` executable is in the correct location.
    public static var caffeinateExists: Bool {
        get {
            return FileManager.default.fileExists(atPath: caffeinatePath.path)
        }
    }
    
    /// The raw `caffeinate` process, if one exists.
    private var proc: Process?
    
    /// If `true`, will automatically set the `caffeinate` process to terminate with this application's termination (when the `.process` option is not passed). Has no bearing on traps.
    public var limitCaffeinationLifetime = true
    
    /// The function to be executed once the Caffeination terminates.
    public var terminationHandler: ((Caffeination) -> Void)?
    
    /// The options for the Caffeination.
    public var opts: [Opt] = [] {
        didSet {
            if isActive {
                Logger.log(.warning, "Options were changed for a Caffeination that is already ongoing. These changes will not take effect until the Caffeination is restarted.")
            }
        }
    }
    
    /// Whether a Caffeination is currently ongoing.
    public var isActive: Bool {
        get {
            guard let proc = proc else {
                return false
            }
            return proc.isRunning
        }
    }
    
    /// Whether the Caffeination will be automatically terminated when the app is quit using the "Quit" menu or receives a termination signal. Setting this property will enable or disable this safety mechanism. Not to be confused
    public var interceptAppTermination: Bool {
        willSet(val) {
            // If this is changed while the Caffeination is in progress, its registration needs to be changed immediately. Otherwise, we can wait for this to take effect the next time the Caffeination starts.
            guard isActive else {
                return
            }
            if val {
                SignalTrapper.shared.register(self)
            } else {
                SignalTrapper.shared.deregister(self)
            }
        }
    }
    
    /**
     Initializes a new Caffeination.
     - Parameters:
        - opts: The options with which to start the Caffeintaion.
        - safety: Whether to enable safety measures to ensure that no "zombie" `caffeinate` processes can outlive the current application. Set to `true` by default, which is recommended.
        - terminationHandler: A handler that will be called when the Caffeination stops. Will be set to `nil` if the parameter is not specified.
     */
   public init(withOpts opts: [Opt] = Opt.defaults, safety: Bool = true, terminationHandler: ((Caffeination) -> Void)? = nil) {
        // TODO: duplicate opt entries need to be disallowed because they result in unexpected behavior
        self.opts = opts
        if safety {
            self.interceptAppTermination = true
        } else {
            limitCaffeinationLifetime = false
            self.interceptAppTermination = false
        }
        if let terminationHandler = terminationHandler {
            self.terminationHandler = terminationHandler
        }
    }
    
    // TODO: Closure arguments are tuples rather than arbitrary in number, although the latter may not be possible.
    
    /**
     Generates a closure that Caffeinates for the duration of its execution. Inherits the Caffeination object's `opts`, of which only `.disk`, `.display`, `.idle`, and `.user` will be honored.
     - Parameter sourceClosure: The closure during which to Caffeinate.
     - Parameter parameter: A parameter of any type.
     - Returns: A closure that will create an active Caffeination for the duration of its synchronous execution.
     - Throws: `CaffeinationError.alreadyActive` if a Caffeination is already active.
    */
    public func closure<Param, Ret>(_ sourceClosure: @escaping (_ parameter: Param) -> Ret) throws -> (Param) -> Ret {
        try preCaffeinateSafetyCheck()
        return { (param: Param) -> Ret in
            try! self.start()
            let ret = sourceClosure(param)
            self.stop()
            return ret
        }
    }
    
    /**
     Generates a Caffienated closure not associated with any Caffeination instance. Only the `.disk`, `.display`, `.idle`, and `.user` options will be honored.
     - Parameters:
        - opts: The options with which to initiate the closure's Caffeination, which may be any of `.idle`, `.display`, `.disk`, and `.user`. All others will be silently ignored.
        - sourceClosure: The closure for the duration of which the Caffeination will be active.
        - parameter: A parameter of any type.
     - Returns: A closure that will create an active Caffeination for the duration of its synchronous execution.
     - Throws: `CaffeinationError.caffeinateNotFound` if the `caffeinate` executable does not exist.
     */
    public static func closure<Param, Ret>(withOpts opts: [Opt] = Opt.defaults, _ sourceClosure: @escaping (_ parameter: Param) -> Ret) throws -> (Param) -> Ret {
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
            let ret = sourceClosure(param)
            proc.terminate()
            return ret
        }
    }
    
    /**
     Generates a Caffienated closure not associated with any Caffeination instance. Only the `.disk`, `.display`, `.idle`, and `.user` options will be honored. Prioritizes the return of a closure and will allow the closure to run even if the `caffeinate` executable is not found. Manually use `Caffeination.caffeinateExists` to check that the intended behavior will occur.
     - Parameters:
        - opts: The options with which to initiate the closure's Caffeination, which may be any of `.idle`, `.display`, `.disk`, and `.user`. All others will be silently ignored.
        - sourceClosure: The closure for the duration of which the Caffeination will be active.
        - parameter: A parameter of any type.
     - Returns: A closure that will create an active Caffeination for the duration of its synchronous execution.
    */
    public static func unsafeClosure<Param, Ret>(withOpts opts: [Opt] = Opt.defaults, _ sourceClosure: @escaping (_ parameter: Param) -> Ret) -> (Param) -> Ret {
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
            let ret = sourceClosure(param)
            proc?.terminate()
            return ret
        }
    }
    
    /**
     Starts preventing sleep (i.e., the Caffeination).
     - Throws: `CaffeinationError.alreadyActive` if a Caffeination is already active, `CaffeinationError.caffeinateNotFound` if the user does not have the caffeinate binary at the expected location, or any error generated by `Process.run()` on macOS 10.13 or higher.
     - Warning: This method could theoretically raise an `NSInvalidArgumentException` if run under exceptional conditions on macOS < 10.13. While every attempt is made to eliminate potential causes of an `NSInvalidArgumentException`, it is still possible that such an exception—which cannot be caught in Swift—could be raised.
    */
    public func start() throws {
        try preCaffeinateSafetyCheck()
        proc = Process.caffeinate(opts: opts, allowingFinite: true, safetyCheck: limitCaffeinationLifetime)
        proc?.terminationHandler = procDidTerminate
        
        if #available(macOS 10.13, *) {
            do {
                try proc?.run()
                SignalTrapper.shared.register(self)
            } catch let err {
                throw err
            }
        } else {
            // TODO: Obj-C catching
            proc?.launch()
        }
    }
    
    /**
     Starts preventing sleep (i.e., the Caffeination) with the specified options, overriding any that may have previously been set.
     - Parameter opts: The options with which to start the Caffeination (overrides the existing value of `self.opts`).
     - Throws: `CaffeinationError.alreadyActive` if a Caffeination is already active, `CaffeinationError.caffeinateNotFound` if the user does not have the caffeinate binary at the expected location, or any error generated by `Process.run()` on macOS 10.13 or higher.
     - Warning: This method could theoretically raise an `NSInvalidArgumentException` if run under exceptional conditions on macOS < 10.13. While every attempt is made to eliminate potential causes of an `NSInvalidArgumentException`, it is still possible that such an exception—which cannot be caught in Swift—could be raised.
    */
    public func start(withOpts opts: [Opt]) throws {
        self.opts = opts
        try start()
    }
    
    /// Stops the Caffeination if it is active.
    public func stop() {
        if isActive {
            proc?.terminate()
            proc?.waitUntilExit()
        }
    }
    
    /**
     Sets the verbosity level of logging.
     - Parameter level: A `LogLevel` specifying the types of logs to receive. Levels are cumulative (i.e., setting the log level to `.info` will also print warnings and errors). Pass `.none` to disable logging.
    */
    public static func setLogLevel(_ level: LogLevel) {
        Logger.logLevel = level
    }
    
    /// Ensures that the Caffeinate executable exists and that no Caffeination is already active.
    private func preCaffeinateSafetyCheck() throws {
        guard isActive == false else {
            throw CaffeinationError.alreadyActive
        }
        guard Caffeination.caffeinateExists else {
            throw CaffeinationError.caffeinateNotFound
        }
    }
    
    // Allows the termination handler to be mutated even after the process has started
    private func procDidTerminate(proc: Process) {
        SignalTrapper.shared.deregister(self)
        terminationHandler?(self)
    }
}
