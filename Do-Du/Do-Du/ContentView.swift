//
//  ContentView.swift
//  Do-Du
//
//  Root navigation. `.sidebarAdaptable` renders a sidebar on macOS and a tab bar on iPhone.
//

import SwiftUI
import SwiftData
import CoreData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            Tab("Today", systemImage: "sun.max") {
                NavigationStack { TodayView() }
            }
            Tab("Tasks", systemImage: "checklist") {
                NavigationStack { TasksView() }
            }
            Tab("Assistant", systemImage: "sparkles") {
                NavigationStack { AssistantView() }
            }
            Tab("Stats", systemImage: "chart.bar") {
                NavigationStack { StatsView() }
            }
            Tab("Projects", systemImage: "folder") {
                NavigationStack { ProjectsView() }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .onChange(of: scenePhase, initial: true) {
            guard scenePhase == .active else { return }
            TimerService.resolveConflicts(in: context)
            // Timer may have been started on another device.
            LongRunAlert.schedule(from: TimerService.current(in: context)?.start)
        }
        // CloudKit import landed: another device may have started a timer.
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)) { _ in
            TimerService.resolveConflicts(in: context)
            LongRunAlert.schedule(from: TimerService.current(in: context)?.start)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: allModels, inMemory: true)
}
