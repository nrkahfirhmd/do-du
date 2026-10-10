//
//  ContentView.swift
//  Do-Du
//
//  Root navigation. `.sidebarAdaptable` renders a sidebar on macOS and a tab bar on iPhone.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Tasks", systemImage: "checklist") {
                NavigationStack { TasksView() }
            }
            Tab("Projects", systemImage: "folder") {
                NavigationStack { ProjectsView() }
            }
            #if !os(macOS)
            Tab("Settings", systemImage: "gear") {
                NavigationStack { SettingsView() }
            }
            #endif
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: allModels, inMemory: true)
}
