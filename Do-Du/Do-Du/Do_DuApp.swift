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
    var sharedModelContainer: ModelContainer = {
        let schema = Schema(allModels)
        // Group container so the widget extension reads the same store.
        // Falls back to the default location when the App Group is
        // unavailable (e.g. unsigned builds).
        SharedStore.migrateIfNeeded()
        let modelConfiguration: ModelConfiguration
        if let url = SharedStore.storeURL(groupURL: SharedStore.groupURL) {
            modelConfiguration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .automatic)
        } else {
            // `.automatic` syncs to the first iCloud container in the entitlements;
            // without entitlements (e.g. unsigned builds) it stays local-only.
            modelConfiguration = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        }

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

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
