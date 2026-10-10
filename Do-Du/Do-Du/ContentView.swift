//
//  ContentView.swift
//  Do-Du
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(sort: \Project.createdAt) private var projects: [Project]

    var body: some View {
        List(projects) { Text($0.name) }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: allModels, inMemory: true)
}
