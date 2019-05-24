//
//  SignalTrapper.swift
//  CaffeineKit
//
//  Created by aaplmath on 8/15/18.
//

import Cocoa

/// Responsible for trapping signals sent to the app
internal final class SignalTrapper {
    static let shared: SignalTrapper = SignalTrapper()
    private var cafs: [Caffeination] = []
    
    var interceptingNotification = false
    var trappedSignals: [Int32] = []
    
    private init() {
        for signal in [SIGABRT, SIGHUP, SIGINT, SIGQUIT, SIGTERM] {
            try! addSignal(signal) // no signals have been added yet, so this is safe
        }
        registerNotificationObserver()
    }
    
    /**
     Registers a Caffeination for safe termination prior to app termination. If the Caffeination has already been registered, it will be ignored.
     - Parameter caffeination: The Caffeination to register.
    */
    func register(_ caffeination: Caffeination) {
        guard !cafs.contains(where: { $0 === caffeination }) else {
            return
        }
        cafs.append(caffeination)
    }
    
    /**
     Removes a Caffeination from the registry for safe termination. By calling this method, you assume responsibility for safely terminating the Caffeination prior to app termination.
     - Parameter caffeination: The Caffeination to deregister.
    */
    func deregister(_ caffeination: Caffeination) {
        cafs.removeAll { $0 === caffeination }
    }
    
    @objc private func trapHandler() {
        cafs.forEach { $0.stop() }
    }
    
    /**
     Adds a trap to intercept a signal. Useful for ensuring that the `caffeinate` process is terminated prior to app termination. Can only be called once per signal, and a trap cannot be removed once it has been created.
     - Parameter sig: The signal to trap (e.g., SIGHUP, SIGINT).
     - Throws: `SignalError.duplicateSignalAdded` if an attempt is made to trap a signal that is already being trapped.
     */
    private func addSignal(_ sig: Int32) throws {
        if !trappedSignals.contains(sig) {
            signal(sig) { closureSig in
                SignalTrapper.shared.trapHandler()
                NSApplication.shared.terminate(SignalTrapper.shared)
            }
            trappedSignals.append(sig)
        } else {
            throw SignalError.duplicateSignalAdded
        }
    }
    
    private func registerNotificationObserver() {
        if !interceptingNotification {
            NotificationCenter.default.addObserver(self, selector: #selector(SignalTrapper.shared.trapHandler), name: NSApplication.willTerminateNotification, object: nil)
            interceptingNotification = true
        }
    }
    
    private func deregisterNotificationObserver() {
        if interceptingNotification {
            NotificationCenter.default.removeObserver(self)
            interceptingNotification = false
        }
    }
}
