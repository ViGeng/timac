//
//  ContentView.swift
//  Timac
//
//  Created by Wei GENG on 29.01.26.
//

import SwiftUI
import CoreData
import Combine
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject private var tracker = AppTracker.shared
    @ObservedObject private var loginItemManager = LoginItemManager.shared
    @State private var usageStats: [AppUsageSummary] = []
    @State private var selectedTimeScale: TimeScale = .today
    @State private var showResetAlert = false
    
    private let refreshTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private var maxDuration: TimeInterval {
        usageStats.first?.totalDuration ?? 1
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Time scale picker
            Picker("", selection: $selectedTimeScale) {
                ForEach(TimeScale.allCases, id: \.self) { scale in
                    Text(scale.rawValue).tag(scale)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 8)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            Divider()
            
            // App list
            if usageStats.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "chart.bar")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No data yet")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                // Column headers
                HStack(spacing: 6) {
                    Spacer()
                        .frame(width: 24) // Icon space
                    
                    Text("App")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("Median")
                        .frame(width: 50, alignment: .center)
                    
                    Text("Total")
                        .frame(width: 80, alignment: .center)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 4)
                
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(usageStats) { stat in
                            AppUsageRow(stat: stat, maxDuration: maxDuration)
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                }
            }
            
            Divider()
            
            // Controls
            HStack(spacing: 8) {
                Toggle(isOn: Binding(
                    get: { tracker.isTracking },
                    set: { _ in toggleTracking() }
                )) {
                    Text("Record")
                        .font(.system(size: 11))
                }
                .toggleStyle(.switch)
                .controlSize(.mini)
                
                Button(action: { showResetAlert = true }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .help("Reset all data")
                
                Button(action: exportToCSV) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .help("Export to CSV")
                
                Spacer()
                
                Toggle(isOn: $loginItemManager.isEnabled) {
                    Text("Autolaunch")
                        .font(.system(size: 11))
                }
                .toggleStyle(.switch)
                .controlSize(.mini)
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(width: 380, height: 400)
        .onAppear {
            refreshStats()
        }
        .onReceive(refreshTimer) { _ in
            refreshStats()
        }
        .onChange(of: selectedTimeScale) { _, _ in
            refreshStats()
        }
        .alert("Reset All Data?", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetAllData()
            }
        } message: {
            Text("This will permanently delete all app usage history. This action cannot be undone.")
        }
    }
    
    private func toggleTracking() {
        if tracker.isTracking {
            tracker.stopTracking()
        } else {
            tracker.startTracking()
        }
    }
    
    private func refreshStats() {
        usageStats = AppUsageStats.fetchUsage(context: viewContext, timeScale: selectedTimeScale)
    }
    
    private func resetAllData() {
        // Stop tracking first
        tracker.stopTracking()
        
        // Delete all records
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = AppUsageRecord.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try viewContext.execute(deleteRequest)
            try viewContext.save()
            usageStats = []
        } catch {
            print("Failed to reset data: \(error)")
        }
        
        // Resume tracking
        tracker.startTracking()
    }
    
    private func exportToCSV() {
        // Fetch all records
        let fetchRequest: NSFetchRequest<AppUsageRecord> = AppUsageRecord.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \AppUsageRecord.frontBegin, ascending: true)]
        
        do {
            let records = try viewContext.fetch(fetchRequest)
            
            // Build CSV content
            var csvContent = "App Name,Bundle ID,Start Time,End Time,Duration (seconds)\n"
            let dateFormatter = ISO8601DateFormatter()
            
            for record in records {
                let appName = record.appName ?? "Unknown"
                let bundleId = record.bundleIdentifier ?? ""
                let startTime = record.frontBegin.map { dateFormatter.string(from: $0) } ?? ""
                let endTime = record.frontEnd.map { dateFormatter.string(from: $0) } ?? ""
                let duration: TimeInterval
                if let begin = record.frontBegin {
                    let end = record.frontEnd ?? Date()
                    duration = end.timeIntervalSince(begin)
                } else {
                    duration = 0
                }
                
                // Escape fields with commas or quotes
                let escapedAppName = appName.contains(",") || appName.contains("\"") 
                    ? "\"\(appName.replacingOccurrences(of: "\"", with: "\"\""))\"" 
                    : appName
                
                csvContent += "\(escapedAppName),\(bundleId),\(startTime),\(endTime),\(Int(duration))\n"
            }
            
            // Show save panel
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [.commaSeparatedText]
            savePanel.nameFieldStringValue = "timac_export_\(Date().formatted(.dateTime.year().month().day())).csv"
            savePanel.title = "Export App Usage Data"
            savePanel.message = "Choose where to save the CSV file"
            
            if savePanel.runModal() == .OK, let url = savePanel.url {
                try csvContent.write(to: url, atomically: true, encoding: .utf8)
            }
        } catch {
            print("Failed to export data: \(error)")
        }
    }
}

struct AppUsageRow: View {
    let stat: AppUsageSummary
    let maxDuration: TimeInterval
    
    private var barRatio: CGFloat {
        guard maxDuration > 0 else { return 0 }
        return CGFloat(stat.totalDuration / maxDuration)
    }
    
    // Focus quality based on median duration
    private var focusQuality: (color: Color, label: String) {
        let median = stat.medianDuration
        if median >= 120 { // >= 2 minutes = deep focus
            return (.green, "Deep")
        } else if median >= 30 { // >= 30 seconds = moderate
            return (.yellow, "Moderate")
        } else { // < 30 seconds = scattered
            return (.orange, "Scattered")
        }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            // App icon
            AppIconView(bundleIdentifier: stat.bundleIdentifier)
                .frame(width: 24, height: 24)
            
            Text(stat.appName)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Median focus time as colored pill badge
            ZStack(alignment: .center) {
                Capsule()
                    .fill(focusQuality.color)
                    .frame(width: 44, height: 18)
                
                Text(stat.formattedMedianDuration)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, alignment: .center)
            }
            .frame(width: 50, height: 18, alignment: .center)
            .help("\(focusQuality.label) focus")
            
            // Duration bar with text inside, right-aligned
            ZStack(alignment: .trailing) {
                // Background track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 80, height: 20)
                
                // Fill bar (right-aligned, grows from right)
                GeometryReader { geo in
                    HStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.accentColor.opacity(0.6))
                            .frame(width: geo.size.width * barRatio)
                    }
                }
                .frame(width: 80, height: 20)
                
                // Duration text overlay
                Text(stat.formattedDuration)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 6)
            }
            .frame(width: 80, height: 20)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(6)
    }
}

struct AppIconView: View {
    let bundleIdentifier: String?
    
    var body: some View {
        if let bundleId = bundleIdentifier,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "app.fill")
                .font(.system(size: 18))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
