//
//  ProjectsView.swift
//  Do-Du
//

import SwiftUI
import SwiftData

struct ProjectsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Project.createdAt) private var projects: [Project]
    @State private var editing: Project?
    @State private var creating = false
    @State private var deleting: Project?
    @State private var showArchived = false

    var body: some View {
        List {
            Section("Active") {
                ForEach(projects.filter { !$0.isArchived }) { row($0) }
            }
            let archived = projects.filter(\.isArchived)
            if !archived.isEmpty {
                Section("Archived", isExpanded: $showArchived) {
                    ForEach(archived) { row($0) }
                }
            }
        }
        .overlay {
            if projects.isEmpty {
                ContentUnavailableView("No projects", systemImage: "folder",
                                       description: Text("Create a project with a daily target to start tracking."))
            }
        }
        .navigationTitle("Projects")
        .toolbar {
            Button("New Project", systemImage: "plus") { creating = true }
        }
        .sheet(isPresented: $creating) { ProjectEditor(project: nil) }
        .sheet(item: $editing) { ProjectEditor(project: $0) }
        .confirmationDialog("Delete \(deleting?.name ?? "project")?", isPresented: .init(
            get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Delete Project, Tasks and Time", role: .destructive) {
                if let deleting { context.delete(deleting) }
            }
        } message: {
            Text("All tasks and tracked time in this project are removed. Archive instead to keep history.")
        }
    }

    private func row(_ p: Project) -> some View {
        HStack {
            ColorDot(color: p.color)
            Text(p.name)
            Spacer()
            Text("\(p.dailyTarget.hoursMinutes)/day").foregroundStyle(.secondary).monospacedDigit()
        }
        .contentShape(Rectangle())
        .onTapGesture { editing = p }
        .contextMenu {
            Button("Edit") { editing = p }
            Button(p.isArchived ? "Unarchive" : "Archive") { p.isArchived.toggle() }
            Button("Delete…", role: .destructive) { deleting = p }
        }
        .swipeActions {
            Button("Delete", role: .destructive) { deleting = p }
            Button(p.isArchived ? "Unarchive" : "Archive") { p.isArchived.toggle() }.tint(.gray)
        }
    }
}

struct ProjectEditor: View {
    let project: Project?
    @Environment(\.modelContext) private var context
    @State private var name = ""
    @State private var colorName = Palette.names[0]
    @State private var targetMinutes = 120
    @State private var mask = Weekdays.monToFri

    var body: some View {
        EditorSheet(title: project == nil ? "New Project" : "Edit Project", canSave: !name.isBlank, save: save) {
            TextField("Name", text: $name)
            ColorChoice(selection: $colorName)
            Stepper("Daily target: \(TimeInterval(targetMinutes * 60).hoursMinutes)",
                    value: $targetMinutes, in: 0...(24 * 60), step: 15)
            WeekdayPicker(mask: $mask)
        }
        .onAppear {
            guard let project else { return }
            name = project.name
            colorName = project.colorName
            targetMinutes = project.dailyTargetMinutes
            mask = project.activeWeekdaysMask
        }
    }

    private func save() {
        let p = project ?? Project(name: "")
        p.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        p.colorName = colorName
        p.dailyTargetMinutes = targetMinutes
        p.activeWeekdaysMask = mask
        if project == nil { context.insert(p) }
    }
}

#Preview {
    NavigationStack { ProjectsView() }
        .modelContainer(for: allModels, inMemory: true)
}
