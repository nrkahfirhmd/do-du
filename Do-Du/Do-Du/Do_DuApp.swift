//
//  Do_DuApp.swift
//  Do-Du
//
//  Created by Nurkahfi Rahmada on 10/10/26.
//

import SwiftUI
import SwiftData

@main
struct Do_DuApp: App {
    /// Same instance Siri/Shortcuts intents use (App Group store, CloudKit unless turned off).
    /// Nil until onboarding finishes on a fresh install, so its iCloud choice decides how the store opens.
    @State private var container: ModelContainer? = OnboardingGate.isNeeded ? nil : Do_DuApp.openStore()

    init() {
        #if canImport(UIKit)
        DD.applyAppearance()
        #endif
    }

    /// Opens the shared store and starts the services that watch the timer.
    private static func openStore() -> ModelContainer {
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

    /// Saves the answers (nil = iCloud already had data), then opens the store.
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
            opened.mainContext.insert(Project(name: answers.trimmedName, colorName: answers.colorName,
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
        MenuBarExtra(isInserted: .constant(container != nil)) {
            if let container { MenuBarPanel().modelContainer(container) }
        } label: {
            if let container { MenuBarLabel().modelContainer(container) }
        }
        .menuBarExtraStyle(.window)

        Settings {
            if let container {
                SettingsView().modelContainer(container)
            } else {
                Text("Finish setting up Do-Du first.").padding(40)
            }
        }
        #endif
    }
}
