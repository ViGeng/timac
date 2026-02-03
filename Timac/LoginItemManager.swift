//
//  LoginItemManager.swift
//  Timac
//
//  Created by Gemini on 03.02.26.
//

import Foundation
import ServiceManagement
import Combine

/// Manages the app's login item status using macOS ServiceManagement framework
class LoginItemManager: ObservableObject {
    static let shared = LoginItemManager()
    
    @Published var isEnabled: Bool {
        didSet {
            if isEnabled {
                enable()
            } else {
                disable()
            }
        }
    }
    
    private init() {
        // Read current status on init
        isEnabled = SMAppService.mainApp.status == .enabled
    }
    
    /// Refresh the current status from the system
    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }
    
    private func enable() {
        do {
            try SMAppService.mainApp.register()
        } catch {
            print("Failed to enable login item: \(error)")
            // Revert the published value on failure
            DispatchQueue.main.async {
                self.isEnabled = false
            }
        }
    }
    
    private func disable() {
        do {
            try SMAppService.mainApp.unregister()
        } catch {
            print("Failed to disable login item: \(error)")
            // Revert the published value on failure
            DispatchQueue.main.async {
                self.isEnabled = true
            }
        }
    }
}
