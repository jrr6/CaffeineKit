//
//  SignalTrapper.swift
//  CaffeineKit
//
//  Created by aaplmath on 8/15/18.
//

import Darwin

/// Responsible for trapping signals sent to the app
internal final class SignalTrapper {
    static var signalHandler: () -> Void = {}
    
    var trappedSignals: [Int32] = []
    
    init(withHandler userHandler: @escaping () -> Void) {
        SignalTrapper.signalHandler = userHandler
    }
    
    func addSignal(_ signal: Int32) throws {
        if !trappedSignals.contains(signal) {
            trapSignal(signal)
        } else {
            throw SignalError.duplicateSignalAdded
        }
    }
    
    private func trapSignal(_ sig: Int32) {
        signal(sig) { signal in
            SignalTrapper.signalHandler()
        }
        trappedSignals.append(sig)
    }
}
