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
    private let viewContext: NSManagedObjectContext
    
    private init() {
        self.viewContext = PersistenceController.shared.container.viewContext
        // Start tracking by default
        startTracking()
    }
    
    func startTracking() {
        guard !isTracking else { return }
        isTracking = true
        
        // Record the current frontmost app
        if let app = NSWorkspace.shared.frontmostApplication {
            startRecordingApp(app)
        }
        
        // Observe app activation changes
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            let bundleId = app.bundleIdentifier
            let appName = app.localizedName
            
            Task { @MainActor [weak self] in
                guard let self = self, self.isTracking else { return }
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
}
