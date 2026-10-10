//
//  ContentView.swift
//  Do-Du
//
//  Root navigation. `.sidebarAdaptable` renders a sidebar on macOS and a tab bar on iPhone.
//

import SwiftUI
import SwiftData
import CoreData

enum AppTab: Hashable { case today, tasks, assistant, stats, projects }

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(filter: #Predicate<TimeEntry> { $0.end == nil }, sort: \TimeEntry.start, order: .reverse)
    private var running: [TimeEntry]
    @State private var tab = AppTab.today
    @AppStorage("assistantMode") private var assistantMode = AssistantView.Mode.recap

    var body: some View {
        TabView(selection: $tab) {
            Tab("Today", systemImage: "sun.max", value: AppTab.today) {
                NavigationStack { TodayView() }.tint(DD.sage)
            }
            Tab("Tasks", systemImage: "checklist", value: AppTab.tasks) {
                NavigationStack { TasksView() }.tint(DD.sage)
            }
            Tab("Assistant", systemImage: "sparkles", value: AppTab.assistant) {
                NavigationStack { AssistantView() }.tint(DD.sage)
            }
            Tab("Stats", systemImage: "chart.bar", value: AppTab.stats) {
                NavigationStack { StatsView() }.tint(DD.sage)
            }
            Tab("Projects", systemImage: "folder", value: AppTab.projects) {
                NavigationStack { ProjectsView() }.tint(DD.sage)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        // Selected tab in forest; content keeps sage links.
        .tint(DD.forest)
        #if os(iOS)
        // Running timer stays visible and stoppable on every tab except Today.
        // Hidden in Chat too, where the message field needs the space.
        .tabViewBottomAccessory(isEnabled: running.first != nil && tab != .today
                                && !(tab == .assistant && assistantMode == .chat)) {
            if let entry = running.first {
                TimerAccessory(entry: entry) { tab = .today }
            }
        }
        #endif
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
