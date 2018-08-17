//
//  Logger.swift
//  CaffeineKit
//
//  Created by aaplmath on 8/15/18.
//

import Foundation

/// Manages logging
internal class Logger {
    
    static var logLevel = LogLevel.info
    
    static func log(_ level: LogLevel, _ string: String) {
        if level.rawValue >= logLevel.rawValue {
            print("[\(level.description)] \(string)")
        }
    }
}
