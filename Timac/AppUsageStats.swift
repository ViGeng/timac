//
//  AppUsageStats.swift
//  Timac
//
//  Provides statistics for app usage time.
//

import Foundation
import CoreData

enum TimeScale: String, CaseIterable {
    case today = "Today"
    case thisWeek = "This Week"
    case last7Days = "Last 7 Days"
    case lastMonth = "Last Month"
    
    var startDate: Date {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .today:
            return calendar.startOfDay(for: now)
        case .thisWeek:
            return calendar.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: now).date ?? now
        case .last7Days:
            return calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: now)) ?? now
        case .lastMonth:
            return calendar.date(byAdding: .month, value: -1, to: calendar.startOfDay(for: now)) ?? now
        }
    }
}

struct AppUsageSummary: Identifiable {
    let id = UUID()
    let appName: String
    let totalDuration: TimeInterval
    
    var formattedDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        let seconds = Int(totalDuration) % 60
        
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}

class AppUsageStats {
    static func fetchUsage(context: NSManagedObjectContext, timeScale: TimeScale) -> [AppUsageSummary] {
        let startDate = timeScale.startDate
        
        let fetchRequest: NSFetchRequest<AppUsageRecord> = AppUsageRecord.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "frontBegin >= %@", startDate as NSDate)
        
        do {
            let records = try context.fetch(fetchRequest)
            return aggregateRecords(records)
        } catch {
            print("Failed to fetch records: \(error)")
            return []
        }
    }
    
    private static func aggregateRecords(_ records: [AppUsageRecord]) -> [AppUsageSummary] {
        var appDurations: [String: TimeInterval] = [:]
        let now = Date()
        
        for record in records {
            guard let appName = record.appName, let begin = record.frontBegin else { continue }
            let end = record.frontEnd ?? now
            let duration = end.timeIntervalSince(begin)
            
            appDurations[appName, default: 0] += duration
        }
        
        return appDurations
            .map { AppUsageSummary(appName: $0.key, totalDuration: $0.value) }
            .sorted { $0.totalDuration > $1.totalDuration }
    }
}
