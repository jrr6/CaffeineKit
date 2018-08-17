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
        proc.launchPath = Caffeination.caffeinatePath
        proc.standardError = FileHandle.nullDevice
        proc.arguments = [] // Enables all the force-unwrapping later on
        
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
            switch opt {
            case .disk:
                proc.arguments!.append("-m")
            case .display:
                proc.arguments!.append("-d")
            case .idle:
                proc.arguments!.append("-i")
            case let .timed(seconds) where allowingFinite:
                proc.arguments! += ["-t", String(seconds)]
            case let .process(pid) where allowingFinite:
                proc.arguments! += ["-w", String(pid)]
            default:
                break
            }
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
