//
//  Enums.swift
//  CaffeineKit
//
//  Created by aaplmath on 8/15/18.
//

/// Indicates the level of logging to be performed by CaffeineKit.
public enum LogLevel: Int {
    /// All logs.
    case info = 0
    
    /// All error- and warning-level logs.
    case warning = 1
    
    /// Error logs only.
    case error = 2
    
    /// Logging disabled.
    case none = 3
    
    internal var description: String {
        switch self {
        case .info:
            return "INFO"
        case .warning:
            return "WARNING"
        case .error:
            return "ERROR"
        default:
            return "unknown"
        }
    }
}

/// An error related to signal trapping.
public enum SignalError: Error {
    /// Indicates that an attempt was made to add a trap for a signal that is already being trapped.
    case duplicateSignalAdded
}

/// An error related to core CaffeineKit functionality.
public enum CaffeinationError: Swift.Error {
    /// Thrown if the caffeinate executable cannot be found.
    case caffeinateNotFound
    
    /// Thrown if an attempt is made to start a Caffeination on an already-active instance.
    case alreadyActive
}
