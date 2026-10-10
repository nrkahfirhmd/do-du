//
//  SettingsView.swift
//  Do-Du
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    var body: some View {
        Form {
            CategoriesSection()
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        #if os(macOS)
        .frame(width: 460, height: 420)
        #endif
    }
}

struct CategoriesSection: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Category.name) private var categories: [Category]
    @State private var editing: Category?
    @State private var creating = false

    var body: some View {
        Section {
            ForEach(categories) { c in
                HStack {
                    ColorDot(color: c.color)
                    Text(c.name)
                    Spacer()
                    Button("Edit") { editing = c }.buttonStyle(.borderless)
                    Button("Delete", systemImage: "trash", role: .destructive) { context.delete(c) }
                        .labelStyle(.iconOnly).buttonStyle(.borderless)
                }
            }
            Button("Add Category", systemImage: "plus") { creating = true }
        } header: {
            Text("Categories")
        } footer: {
            Text("Deleting a category keeps its tasks; they just become uncategorized.")
        }
        .sheet(isPresented: $creating) { CategoryEditor(category: nil) }
        .sheet(item: $editing) { CategoryEditor(category: $0) }
    }
}

struct CategoryEditor: View {
    let category: Category?
    @Environment(\.modelContext) private var context
    @State private var name = ""
    @State private var colorName = Palette.names[0]

    var body: some View {
        EditorSheet(title: category == nil ? "New Category" : "Edit Category", canSave: !name.isBlank) {
            let c = category ?? Category(name: "")
            c.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            c.colorName = colorName
            if category == nil { context.insert(c) }
        } content: {
            TextField("Name", text: $name)
            ColorChoice(selection: $colorName)
        }
        .onAppear {
            name = category?.name ?? ""
            colorName = category?.colorName ?? Palette.names[0]
        }
    }
}
