//
//  ContentView.swift
//  Timac
//
//  Created by Wei GENG on 29.01.26.
//

import SwiftUI
import CoreData
import Combine

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject private var tracker = AppTracker.shared
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
                Button(action: toggleTracking) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(tracker.isTracking ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                        Image(systemName: tracker.isTracking ? "pause.fill" : "play.fill")
                            .font(.system(size: 11))
                        Text(tracker.isTracking ? "Pause" : "Start")
                    }
                }
                .buttonStyle(.bordered)
                
                Button(action: { showResetAlert = true }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .help("Reset all data")
                
                Spacer()
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(width: 300, height: 400)
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
}

struct AppUsageRow: View {
    let stat: AppUsageSummary
    let maxDuration: TimeInterval
    
    private var barRatio: CGFloat {
        guard maxDuration > 0 else { return 0 }
        return CGFloat(stat.totalDuration / maxDuration)
    }
    
    var body: some View {
        HStack(spacing: 10) {
            // App icon
            AppIconView(bundleIdentifier: stat.bundleIdentifier)
                .frame(width: 24, height: 24)
            
            Text(stat.appName)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Duration bar + text
            HStack(spacing: 6) {
                // Histogram bar
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.accentColor.opacity(0.7))
                        .frame(width: geo.size.width * barRatio)
                }
                .frame(width: 50, height: 12)
                
                // Duration text with fixed width for alignment
                Text(stat.formattedDuration)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 58, alignment: .trailing)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
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
