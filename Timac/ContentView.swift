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
    
    private let refreshTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 0) {
            // Time scale picker
            Picker("", selection: $selectedTimeScale) {
                ForEach(TimeScale.allCases, id: \.self) { scale in
                    Text(scale.rawValue).tag(scale)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 6)
            
            // Header
            HStack {
                Text("App Usage")
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(tracker.isTracking ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            
            Divider()
            
            // App list
            if usageStats.isEmpty {
                VStack {
                    Spacer()
                    Text("No data yet")
                        .foregroundColor(.secondary)
                    if !tracker.isTracking {
                        Text("Click Start to begin tracking")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(usageStats) { stat in
                            AppUsageRow(stat: stat)
                        }
                    }
                }
            }
            
            Divider()
            
            // Controls
            HStack {
                Button(action: toggleTracking) {
                    HStack(spacing: 4) {
                        Image(systemName: tracker.isTracking ? "pause.fill" : "play.fill")
                        Text(tracker.isTracking ? "Pause" : "Start")
                    }
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)
            }
            .padding(10)
        }
        .frame(width: 300, height: 380)
        .onAppear {
            refreshStats()
        }
        .onReceive(refreshTimer) { _ in
            refreshStats()
        }
        .onChange(of: selectedTimeScale) { _, _ in
            refreshStats()
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
}

struct AppUsageRow: View {
    let stat: AppUsageSummary
    
    var body: some View {
        HStack {
            Text(stat.appName)
                .lineLimit(1)
            Spacer()
            Text(stat.formattedDuration)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
