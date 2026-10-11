import CoreData
import SwiftData
import SwiftUI

enum AppTab: Hashable { case today, tasks, assistant, stats, projects }

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(filter: #Predicate<TimeEntry> { $0.end == nil }, sort: \TimeEntry.start, order: .reverse)
    private var running: [TimeEntry]
    @State private var tab = AppTab.today
    @AppStorage("assistantMode") private var assistantMode = AssistantView.Mode.recap

    var body: some View {
        #if os(macOS)
        MacRootView().modifier(TimerSync()).modifier(AutoImport())
        #else
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
        .tint(DD.forest)
        #if os(iOS)
        .tabViewBottomAccessory(
            isEnabled: running.first != nil && tab != .today
                && !(tab == .assistant && assistantMode == .chat)
        ) {
            if let entry = running.first {
                TimerAccessory(entry: entry) { tab = .today }
            }
        }
        #endif
        .modifier(TimerSync())
        .modifier(AutoImport())
        .onOpenURL { url in
            // Widgets open the app instead of writing data themselves.
            if DeepLink(url) == .toggleTimer { TimerService.toggleQuick(in: context) }
            tab = .today
        }
        #endif
    }
}

/// Resolves duplicate running timers and reschedules the long-run alert on activation and when CloudKit imports land.
struct TimerSync: ViewModifier {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(filter: #Predicate<TimeEntry> { $0.end == nil }) private var running: [TimeEntry]

    func body(content: Content) -> some View {
        content
            .sensoryFeedback(trigger: running.first?.persistentModelID) { old, new in
                switch (old, new) {
                case (nil, .some): .ddStart
                case (.some, nil): .ddStop
                case (.some, .some): .ddSwitch  // switched session
                case (nil, nil): nil
                }
            }
            .onChange(of: scenePhase, initial: true) {
                guard scenePhase == .active else { return }
                TimerService.resolveConflicts(in: context)
                LongRunAlert.schedule(from: TimerService.current(in: context)?.start)
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)) { _ in
                TimerService.resolveConflicts(in: context)
                LongRunAlert.schedule(from: TimerService.current(in: context)?.start)
            }
    }
}

#Preview {
    ContentView()
        .modelContainer(SharedStore.preview)
}
