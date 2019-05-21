//
//  ProcessAdditions.swift
//  CaffeineKit
//
//  Created by aaplmath on 8/16/18.
//

import Foundation

internal extension Process {
    /// Generates a Process for the `caffeinate` executable with the specified `Caffeination.Opts`
    static func caffeinate(opts: [Caffeination.Opt], allowingFinite: Bool, safetyCheck: Bool) -> Process {
        let proc = Process()
        if #available(OSX 10.13, *) {
            proc.executableURL = Caffeination.caffeinatePath
        } else {
            proc.launchPath = Caffeination.caffeinatePath.path
        }
        proc.standardError = FileHandle.nullDevice
        proc.arguments = [] // Enables all the force-unwrapping later on
        
        // Log caffeinate output using Logger
        if Logger.logLevel.rawValue >= LogLevel.error.rawValue {
            if Logger.logLevel.rawValue >= LogLevel.info.rawValue {
                let infoPipe = Pipe()
                proc.standardOutput = infoPipe
                infoPipe.fileHandleForReading.readabilityHandler = { pipe in
                    if let line = String(data: pipe.availableData, encoding: .utf8) {
                        Logger.log(.info, "[caffeinate] \(line)")
                    }
                }
            } else {
                proc.standardOutput = FileHandle.nullDevice
            }
            let errPipe = Pipe()
            proc.standardError = errPipe
            errPipe.fileHandleForReading.readabilityHandler = { pipe in
                if let line = String(data: pipe.availableData, encoding: .utf8) {
                    Logger.log(.error, "[caffeinate] \(line)")
                }
            }
        } else {
            proc.standardError = FileHandle.nullDevice
        }
        
        for opt in opts {
            if !allowingFinite {
                if case .timed = opt {
                    continue
                } else if case .process = opt {
                    continue
                }
            }
            proc.arguments!.append(contentsOf: opt.argumentList)
        }
        
        // Have caffeinate automatically terminate upon the app's termination as an added precuation
        if safetyCheck {
            if !proc.arguments!.contains("-w") {
                proc.arguments! += ["-w", String(ProcessInfo.processInfo.processIdentifier)]
            }
        }
        
        return proc
    }
}
