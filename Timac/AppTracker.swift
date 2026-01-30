//
//  AppTracker.swift
//  Timac
//
//  Tracks the frontmost application and records usage time.
//

import Foundation
import AppKit
import CoreData
import Combine

@MainActor
class AppTracker: ObservableObject {
    static let shared = AppTracker()
    
    @Published var isTracking = false
    @Published private(set) var currentAppName: String?
    
    private var currentRecord: AppUsageRecord?
    private var workspaceObserver: NSObjectProtocol?
    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var wasTrackingBeforeSleep = false
    private let viewContext: NSManagedObjectContext
    
    // Apps to ignore (system processes, not real user apps)
    private let ignoredBundleIdentifiers: Set<String> = [
        "com.apple.loginwindow",
        "com.apple.SecurityAgent",
        "com.apple.UserNotificationCenter",
    ]
    
    private init() {
        self.viewContext = PersistenceController.shared.container.viewContext
        setupSleepWakeObservers()
        // Start tracking by default
        startTracking()
    }
    
    private func setupSleepWakeObservers() {
        // Observe system sleep
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleSystemSleep()
            }
        }
        
        // Observe system wake
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleSystemWake()
            }
        }
    }
    
    private func handleSystemSleep() {
        wasTrackingBeforeSleep = isTracking
        if isTracking {
            // End current record but keep isTracking true for UI
            endCurrentRecord()
        }
    }
    
    private func handleSystemWake() {
        if wasTrackingBeforeSleep && isTracking {
            // Resume tracking the frontmost app after wake
            if let app = NSWorkspace.shared.frontmostApplication {
                if shouldTrackApp(app) {
                    startRecordingApp(app)
                }
            }
        }
    }
    
    private func shouldTrackApp(_ app: NSRunningApplication) -> Bool {
        guard let bundleId = app.bundleIdentifier else { return true }
        return !ignoredBundleIdentifiers.contains(bundleId)
    }
    
    func startTracking() {
        guard !isTracking else { return }
        isTracking = true
        
        // Record the current frontmost app
        if let app = NSWorkspace.shared.frontmostApplication, shouldTrackApp(app) {
            startRecordingApp(app)
        }
        
        // Observe app activation changes
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            
            Task { @MainActor [weak self] in
                guard let self = self, self.isTracking else { return }
                
                // Skip ignored apps
                guard self.shouldTrackApp(app) else { return }
                
                let bundleId = app.bundleIdentifier
                let appName = app.localizedName
                self.switchToApp(name: appName, bundleIdentifier: bundleId)
            }
        }
    }
    
    func stopTracking() {
        guard isTracking else { return }
        isTracking = false
        
        // End current record
        endCurrentRecord()
        
        // Remove observer
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            workspaceObserver = nil
        }
    }
    
    private func switchToApp(name: String?, bundleIdentifier: String?) {
        endCurrentRecord()
        startRecordingApp(name: name, bundleIdentifier: bundleIdentifier)
    }
    
    private func startRecordingApp(_ app: NSRunningApplication) {
        startRecordingApp(name: app.localizedName, bundleIdentifier: app.bundleIdentifier)
    }
    
    private func startRecordingApp(name: String?, bundleIdentifier: String?) {
        let appName = name ?? "Unknown"
        currentAppName = appName
        
        let record = AppUsageRecord(context: viewContext)
        record.appName = appName
        record.bundleIdentifier = bundleIdentifier
        record.frontBegin = Date()
        record.frontEnd = nil
        
        currentRecord = record
        saveContext()
    }
    
    private func endCurrentRecord() {
        guard let record = currentRecord else { return }
        record.frontEnd = Date()
        currentRecord = nil
        currentAppName = nil
        saveContext()
    }
    
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Failed to save context: \(error)")
        }
    }
    
    deinit {
        if let observer = sleepObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        if let observer = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
}
