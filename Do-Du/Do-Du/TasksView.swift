//
//  TasksView.swift
//  Do-Du
//

import SwiftUI
import SwiftData

struct TasksView: View {
    enum Status: String, CaseIterable { case open = "Open", done = "Done", all = "All" }

    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Project> { !$0.isArchived }, sort: \Project.createdAt) private var projects: [Project]
    @Query(sort: \Category.name) private var categories: [Category]
    @State private var status = Status.open
    @State private var categoryFilter: Category?
    @State private var dueTodayOnly = false
    @State private var creating = false
    @State private var editing: TaskItem?

    var body: some View {
        List {
            ForEach(projects) { project in
                let tasks = visibleTasks(in: project)
                if !tasks.isEmpty {
                    Section {
                        ForEach(tasks) { task in
                            TaskRow(task: task)
                                .contentShape(Rectangle())
                                .onTapGesture(count: 2) { editing = task }
                                .contextMenu {
                                    Button("Edit") { editing = task }
                                    Button("Delete", role: .destructive) { context.delete(task) }
                                }
                                .swipeActions {
                                    Button("Delete", role: .destructive) { context.delete(task) }
                                    Button("Edit") { editing = task }
                                }
                        }
                    } header: {
                        Label { Text(project.name) } icon: { ColorDot(color: project.color) }
                    }
                }
            }
        }
        .overlay { emptyState }
        .navigationTitle("Tasks")
        .toolbar {
            ToolbarItem {
                Menu("Filter", systemImage: hasFilter ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle") {
                    Picker("Status", selection: $status) {
                        ForEach(Status.allCases, id: \.self) { Text($0.rawValue) }
                    }
                    Picker("Category", selection: $categoryFilter) {
                        Text("Any category").tag(Category?.none)
                        ForEach(categories) { Text($0.name).tag(Optional($0)) }
                    }
                    Toggle("Due today", isOn: $dueTodayOnly)
                }
            }
            ToolbarItem {
                Button("New Task", systemImage: "plus") { creating = true }
                    .keyboardShortcut("n")
                    .disabled(projects.isEmpty)
            }
        }
        .sheet(isPresented: $creating) { TaskEditor(task: nil) }
        .sheet(item: $editing) { TaskEditor(task: $0) }
    }

    private var hasFilter: Bool { status != .open || categoryFilter != nil || dueTodayOnly }

    private func visibleTasks(in project: Project) -> [TaskItem] {
        let today = DayMath.day(.now)
        return (project.tasks ?? [])
            .filter { status == .all || $0.isDone == (status == .done) }
            .filter { categoryFilter == nil || $0.category == categoryFilter }
            .filter { !dueTodayOnly || ($0.dueDate.map { $0 < today.end } ?? false) }
            .sorted { ($0.dueDate ?? .distantFuture, $0.createdAt) < ($1.dueDate ?? .distantFuture, $1.createdAt) }
    }

    @ViewBuilder private var emptyState: some View {
        if projects.isEmpty {
            ContentUnavailableView("No projects yet", systemImage: "folder.badge.plus",
                                   description: Text("Tasks live inside projects. Create a project first."))
        } else if projects.allSatisfy({ visibleTasks(in: $0).isEmpty }) {
            ContentUnavailableView {
                Label(hasFilter ? "No matching tasks" : "No open tasks", systemImage: "checklist")
            } actions: {
                Button("New Task") { creating = true }
            }
        }
    }
}

struct TaskRow: View {
    let task: TaskItem

    var body: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation { task.setDone(!task.isDone) }
            } label: {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isDone ? .green : .secondary)
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isDone ? "Mark open" : "Mark done")

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title).strikethrough(task.isDone).foregroundStyle(task.isDone ? .secondary : .primary)
                HStack(spacing: 8) {
                    if let c = task.category { Label { Text(c.name) } icon: { ColorDot(color: c.color) } }
                    if let due = task.dueDate {
                        Label(due.formatted(.relative(presentation: .named)), systemImage: "calendar")
                            .foregroundStyle(due < DayMath.day(.now).start && !task.isDone ? .red : .secondary)
                    }
                    if let est = task.estimateMinutes {
                        Label(TimeInterval(est * 60).hoursMinutes, systemImage: "hourglass")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

struct TaskEditor: View {
    let task: TaskItem?
    var defaultProject: Project?
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Project> { !$0.isArchived }, sort: \Project.createdAt) private var projects: [Project]
    @Query(sort: \Category.name) private var categories: [Category]
    @State private var title = ""
    @State private var notes = ""
    @State private var project: Project?
    @State private var category: Category?
    @State private var hasDue = false
    @State private var due = Date.now
    @State private var hasEstimate = false
    @State private var estimate = 30

    var body: some View {
        EditorSheet(title: task == nil ? "New Task" : "Edit Task", canSave: !title.isBlank && project != nil, save: save) {
            TextField("Title", text: $title)
            Picker("Project", selection: $project) {
                if project == nil { Text("Choose…").tag(Project?.none) }
                ForEach(projects) { Text($0.name).tag(Optional($0)) }
            }
            Picker("Category", selection: $category) {
                Text("None").tag(Category?.none)
                ForEach(categories) { Text($0.name).tag(Optional($0)) }
            }
            Toggle("Due date", isOn: $hasDue)
            if hasDue { DatePicker("Due", selection: $due, displayedComponents: .date) }
            Toggle("Estimate", isOn: $hasEstimate)
            if hasEstimate {
                Stepper("Estimate: \(TimeInterval(estimate * 60).hoursMinutes)", value: $estimate, in: 5...(12 * 60), step: 5)
            }
            TextField("Notes", text: $notes, axis: .vertical).lineLimit(3...8)
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard let task else {
            project = defaultProject ?? projects.first
            return
        }
        title = task.title
        notes = task.notes
        project = task.project
        category = task.category
        hasDue = task.dueDate != nil
        due = task.dueDate ?? .now
        hasEstimate = task.estimateMinutes != nil
        estimate = task.estimateMinutes ?? 30
    }

    private func save() {
        let t = task ?? TaskItem(title: "", project: nil)
        t.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        t.notes = notes
        t.project = project
        t.category = category
        t.dueDate = hasDue ? Calendar.current.startOfDay(for: due) : nil
        t.estimateMinutes = hasEstimate ? estimate : nil
        if task == nil { context.insert(t) }
    }
}
