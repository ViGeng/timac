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
    let bundleIdentifier: String?
    let totalDuration: TimeInterval
    let medianDuration: TimeInterval
    
    var formattedDuration: String {
        formatDuration(totalDuration)
    }
    
    var formattedMedianDuration: String {
        formatDuration(medianDuration)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%2dh %2dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%2dm %2ds", minutes, seconds)
        } else {
            return String(format: "    %2ds", seconds)
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
        var appData: [String: (durations: [TimeInterval], bundleId: String?)] = [:]
        let now = Date()
        
        for record in records {
            guard let appName = record.appName, let begin = record.frontBegin else { continue }
            let end = record.frontEnd ?? now
            let duration = end.timeIntervalSince(begin)
            
            if var existing = appData[appName] {
                existing.durations.append(duration)
                existing.bundleId = existing.bundleId ?? record.bundleIdentifier
                appData[appName] = existing
            } else {
                appData[appName] = ([duration], record.bundleIdentifier)
            }
        }
        
        return appData
            .map { (appName, data) in
                let totalDuration = data.durations.reduce(0, +)
                let medianDuration = calculateMedian(data.durations)
                return AppUsageSummary(
                    appName: appName,
                    bundleIdentifier: data.bundleId,
                    totalDuration: totalDuration,
                    medianDuration: medianDuration
                )
            }
            .sorted { $0.totalDuration > $1.totalDuration }
    }
    
    private static func calculateMedian(_ values: [TimeInterval]) -> TimeInterval {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let count = sorted.count
        if count % 2 == 0 {
            return (sorted[count / 2 - 1] + sorted[count / 2]) / 2
        } else {
            return sorted[count / 2]
        }
    }
}
