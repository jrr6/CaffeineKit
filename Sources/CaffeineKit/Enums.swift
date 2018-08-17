//
//  Enums.swift
//  CaffeineKit
//
//  Created by aaplmath on 8/15/18.
//

enum LogLevel: Int {
    case info = 0
    case warning = 1
    case error = 2
    case none = 3
    
    var description: String {
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

public enum SignalError: Error {
    /// Indicates that an attempt was made to add a trap for a signal that is already being trapped
    case duplicateSignalAdded
}

public enum CaffeinationError: Swift.Error {
    /// Thrown if the caffeinate executable cannot be found
    case caffeinateNotFound
    
    /// Thrown if an attempt is made to start a Caffeination on an already-active instance
    case alreadyActive
}
