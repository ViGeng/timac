//
//  Persistence.swift
//  Timac
//
//  Created by Wei GENG on 29.01.26.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Create sample data for preview
        let apps = ["Safari", "Xcode", "Finder", "Terminal", "Messages"]
        let now = Date()
        
        for (index, appName) in apps.enumerated() {
            let record = AppUsageRecord(context: viewContext)
            record.appName = appName
            record.frontBegin = now.addingTimeInterval(Double(-3600 + index * 600))
            record.frontEnd = now.addingTimeInterval(Double(-3000 + index * 600))
        }
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Timac")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Store in iCloud Drive for sync across devices
            if let icloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
                .appendingPathComponent("Documents")
                .appendingPathComponent("Timac") {
                try? FileManager.default.createDirectory(at: icloudURL, withIntermediateDirectories: true)
                let storeURL = icloudURL.appendingPathComponent("Timac.sqlite")
                container.persistentStoreDescriptions.first?.url = storeURL
            }
            // Fallback to local if iCloud not available
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
