import SwiftData
import SwiftUI

@main
struct Do_DuApp: App {
    /// Nil until onboarding finishes, so its iCloud choice decides how the store opens.
    @State private var container: ModelContainer? = OnboardingGate.isNeeded ? nil : Do_DuApp.openStore()
    #if os(macOS)
    @AppStorage(MenuBarVisibility.key) private var showMenuBar = true
    #endif

    init() {
        #if canImport(UIKit)
        DD.applyAppearance()
        #endif
    }

    private static func openStore() -> ModelContainer {
        SyncMonitor.shared.start()
        let container = SharedStore.shared
        LongRunAlert.register(container: container)
        TimerWidget.register(container: container)
        #if os(macOS)
        IdleStop.register(container: container)
        GlobalHotKey.register(container: container)
        #endif
        #if DEBUG
        SampleData.seedIfRequested(container.mainContext)
        #endif
        return container
    }

    private func finishOnboarding(_ answers: OnboardingAnswers?) {
        let defaults = UserDefaults.standard
        if let answers {
            defaults.set(answers.dayStart, forKey: DayMath.startHourKey)
            defaults.set(answers.iCloud, forKey: SharedStore.iCloudKey)
            if !answers.key.isBlank { _ = ClaudeKey.save(answers.key.trimmingCharacters(in: .whitespacesAndNewlines)) }
        }
        defaults.set(true, forKey: OnboardingGate.doneKey)
        let opened = Self.openStore()
        if let answers {
            opened.mainContext.insert(
                Project(
                    name: answers.trimmedName, colorName: answers.colorName,
                    dailyTargetMinutes: answers.targetMinutes,
                    activeWeekdaysMask: answers.weekdayMask))
            try? opened.mainContext.save()
            OnboardingGate.justFinished = true
        }
        container = opened
    }

    var body: some Scene {
        WindowGroup {
            if let container {
                ContentView().modelContainer(container)
            } else {
                OnboardingView(onFinish: finishOnboarding)
                    #if os(macOS)
                .toolbar(removing: .title)
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
                    #endif
            }
        }
        .defaultSize(width: 1280, height: 800)
        #if os(macOS)
        .windowResizability(.contentSize)
        #endif
        .commands {
            CommandMenu("Timer") {
                Button("Stop Timer") { if let container { TimerService.stop(in: container.mainContext) } }
                    .keyboardShortcut(".", modifiers: .command)
                    .disabled(container == nil)
            }
        }

        #if os(macOS)
        // Only a user removal (⌘-drag out) may turn the setting off; the item is also removed while onboarding runs.
        MenuBarExtra(isInserted: Binding(get: { container != nil && showMenuBar }, set: { if container != nil { showMenuBar = $0 } })) {
            if let container { MenuBarPanel().modelContainer(container) }
        } label: {
            if let container { MenuBarLabel().modelContainer(container) }
        }
        .menuBarExtraStyle(.window)

        Settings {
            if let container {
                MacSettingsView().modelContainer(container)
            } else {
                Text("Finish setting up Do-Du first.").padding(40)
            }
        }
        #endif
    }
}
