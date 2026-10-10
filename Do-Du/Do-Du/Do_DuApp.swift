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
    // Same instance Siri/Shortcuts intents use (App Group store, CloudKit sync).
    let sharedModelContainer = SharedStore.shared

    init() {
        LongRunAlert.register(container: sharedModelContainer)
        TimerWidget.register(container: sharedModelContainer)
        #if os(macOS)
        IdleStop.register(container: sharedModelContainer)
        #endif
        #if DEBUG
        SampleData.seedIfRequested(sharedModelContainer.mainContext)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        .commands {
            CommandMenu("Timer") {
                Button("Stop Timer") { TimerService.stop(in: sharedModelContainer.mainContext) }
                    .keyboardShortcut(".", modifiers: .command)
            }
        }

        #if os(macOS)
        MenuBarExtra {
            MenuBarPanel().modelContainer(sharedModelContainer)
        } label: {
            MenuBarLabel().modelContainer(sharedModelContainer)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
        .modelContainer(sharedModelContainer)
        #endif
    }
}
