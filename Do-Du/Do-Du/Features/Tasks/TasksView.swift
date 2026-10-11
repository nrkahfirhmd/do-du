import SwiftData
import SwiftUI

struct TasksView: View {
    enum Status: String, CaseIterable {
        case open = "Open"
        case done = "Done"
        case all = "All"
    }

    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Project> { !$0.isArchived }, sort: \Project.createdAt) private var projects: [Project]
    @Query(sort: \Category.name) private var categories: [Category]
    @State private var status = Status.open
    @State private var categoryFilter: Category?
    @State private var dueTodayOnly = false
    @State private var creating = false
    @State private var editing: TaskItem?
    @State private var entriesFor: TaskItem?
    #if os(iOS)
    @State private var quickAdd = false
    #endif
    @State private var notionImport = false
    @State private var remindersImport = false
    @State private var refreshNote: String?

    var body: some View {
        content
            .background(DD.page)
            .overlay { emptyState }
            #if os(iOS)
        .pullToRefresh($refreshNote, in: context)
            #endif
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem {
                    Menu("Filter", systemImage: hasFilter ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    {
                        #if !os(macOS)
                        Picker("Status", selection: $status) {
                            ForEach(Status.allCases, id: \.self) { Text($0.rawValue) }
                        }
                        #endif
                        Picker("Category", selection: $categoryFilter) {
                            Text("Any category").tag(Category?.none)
                            ForEach(categories) { Text($0.name).tag(Optional($0)) }
                        }
                        Toggle("Due today", isOn: $dueTodayOnly)
                    }
                }
                ToolbarItem {
                    Menu("Import", systemImage: "square.and.arrow.down") {
                        Button("From Notion") { notionImport = true }
                        Button("From Reminders") { remindersImport = true }
                    }
                    .disabled(projects.isEmpty)
                }
                #if os(iOS)
                // Mac has Quick Add (⌘K) in the window toolbar.
                ToolbarItem {
                    Button("Quick Add", systemImage: "sparkles") { quickAdd = true }
                        .keyboardShortcut("k")
                        .disabled(projects.isEmpty)
                }
                #endif
                ToolbarSpacer(.fixed)
                ToolbarItem {
                    Button("New Task", systemImage: "plus") { creating = true }
                        .keyboardShortcut("n")
                        .buttonStyle(.borderedProminent)
                        .tint(DD.forestFill)
                        .disabled(projects.isEmpty)
                }
            }
            .sheet(isPresented: $creating) { TaskEditor(task: nil) }
            .sheet(item: $editing) { TaskEditor(task: $0) }
            .sheet(item: $entriesFor) { TimeEntriesView(task: $0) }
            #if os(iOS)
        .sheet(isPresented: $quickAdd) { QuickAddSheet() }
        #endif
        .sheet(isPresented: $notionImport) { ExternalImportSheet<NotionClient>() }
        .sheet(isPresented: $remindersImport) { ExternalImportSheet<RemindersSource>() }
    }

    #if os(macOS)
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    ForEach(Status.allCases, id: \.self) { s in
                        Button(s.rawValue) { status = s }
                            .buttonStyle(
                                CapsuleButton(
                                    fill: status == s ? DD.forestFill : DD.fill,
                                    ink: status == s ? .white : DD.ink, height: 28))
                    }
                }
                ForEach(projects) { project in
                    let tasks = visibleTasks(in: project)
                    if !tasks.isEmpty {
                        ProjectHeader(project: project, count: tasks.count).padding(.top, 18).padding(.bottom, 8)
                        MacTaskTable(tasks: tasks, edit: { editing = $0 }, entries: { entriesFor = $0 })
                    }
                }
            }
            .padding(EdgeInsets(top: 16, leading: 28, bottom: 28, trailing: 28))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    #else
    private var content: some View {
        List {
            ForEach(projects) { project in
                let tasks = visibleTasks(in: project)
                if !tasks.isEmpty {
                    Section {
                        ForEach(tasks) { task in
                            TaskRow(task: task)
                                .contentShape(Rectangle())
                                .onTapGesture { editing = task }
                                .contextMenu {
                                    Button("Edit") { editing = task }
                                    Button("Time Entries…") { entriesFor = task }
                                    Button("Delete", role: .destructive) { context.delete(task) }
                                }
                                .swipeActions {
                                    Button("Delete", role: .destructive) { context.delete(task) }
                                    Button("Edit") { editing = task }
                                    Button("Time") { entriesFor = task }.tint(.orange)
                                }
                        }
                    } header: {
                        ProjectHeader(project: project, count: tasks.count)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
    #endif

    private var hasFilter: Bool { status != .open || categoryFilter != nil || dueTodayOnly }

    private func visibleTasks(in project: Project) -> [TaskItem] {
        let today = DayMath.logicalDate(.now)
        return (project.tasks ?? [])
            .filter { status == .all || $0.isDone == (status == .done) }
            .filter { categoryFilter == nil || $0.category == categoryFilter }
            .filter { !dueTodayOnly || ($0.dueDate.map { $0 <= today } ?? false) }
            .sorted { ($0.dueDate ?? .distantFuture, $0.createdAt) < ($1.dueDate ?? .distantFuture, $1.createdAt) }
    }

    @ViewBuilder private var emptyState: some View {
        if projects.isEmpty {
            ContentUnavailableView(
                "No projects yet", systemImage: "folder.badge.plus",
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
        HStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { task.setDone(!task.isDone) }
            } label: {
                ZStack {
                    Circle().strokeBorder(task.isDone ? DD.mint : DD.disabled, lineWidth: 2)
                        .background(Circle().fill(task.isDone ? DD.mint : .clear))
                    if task.isDone {
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .black)).foregroundStyle(DD.onMint)
                    }
                }
                .frame(width: 24, height: 24)
                .frame(width: 44, height: 44)
                .sensoryFeedback(.impact(weight: .light), trigger: task.isDone) { _, done in done }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, -10)
            .accessibilityLabel(task.isDone ? "Mark open" : "Mark done")

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title).font(.body).lineLimit(1)
                    .strikethrough(task.isDone)
                    .foregroundStyle(task.isDone ? DD.ink3 : DD.ink)
                if !meta.isEmpty {
                    HStack(spacing: 10) {
                        if let c = task.category {
                            HStack(spacing: 4) {
                                Circle().fill(c.color).frame(width: 7, height: 7)
                                Text(c.name)
                            }
                        }
                        if let due = task.dueDate {
                            Text(
                                "Due "
                                    + (Calendar.current.isDateInToday(due) ? "today" : due.formatted(.dateTime.day().month(.abbreviated)))
                            )
                            .foregroundStyle(due < DayMath.logicalDate(.now) && !task.isDone ? DD.danger : DD.ink3)
                        }
                        if let est = task.estimateMinutes { Text("~" + TimeInterval(est * 60).hoursMinutes) }
                    }
                    .font(.footnote).foregroundStyle(DD.ink3).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if !task.isDone { TimerButton(task: task) }
        }
        .frame(minHeight: 60)
        .listRowBackground(task.isRunning ? DD.runningRow : DD.surface)
    }

    private var meta: [String] {
        [task.category?.name, task.dueDate.map { _ in "due" }, task.estimateMinutes.map { _ in "est" }].compactMap { $0 }
    }
}

struct ProjectHeader: View {
    let project: Project
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Text(project.name).font(.rounded(13, .bold)).foregroundStyle(.white)
                .padding(.horizontal, 10).frame(height: 24)
                .background(headerColor, in: Capsule())
            Text("\(count) task\(count == 1 ? "" : "s")").font(.footnote).foregroundStyle(DD.ink3)
        }
        .textCase(nil)
    }

    /// White text needs a dark enough capsule: the light swatches step down to pine.
    private var headerColor: Color {
        switch Palette.canonical(project.colorName) {
        case "seafoam", "slate": Palette.color("pine")
        case "forest": DD.forestFill
        default: project.color
        }
    }
}

struct TaskEditor: View {
    let task: TaskItem?
    /// New-task starting values (Quick Add). Ignored when editing.
    var prefill: TaskPrefill?
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Project> { !$0.isArchived }, sort: \Project.createdAt) private var projects: [Project]
    @Query(sort: \Category.name) private var categories: [Category]
    @State private var title = ""
    @State private var notes = ""
    @State private var project: Project?
    @State private var category: Category?
    @State private var due: Date?
    /// Minutes; 0 = no estimate.
    @State private var estimate = 0

    var body: some View {
        EditorSheet(
            title: task == nil ? "New Task" : "Edit Task", canSave: !title.isBlank && project != nil, save: save,
            destructive: task.map { t in ("Delete Task", { context.delete(t) }) }
        ) {
            Section { TextField("Title", text: $title).font(.system(size: 17, weight: .semibold)).labelsHidden() }
            Section {
                Picker("Project", selection: $project) {
                    if project == nil { Text("Choose…").tag(Project?.none) }
                    ForEach(projects) { Text($0.name).tag(Optional($0)) }
                }
                Picker("Category", selection: $category) {
                    Text("None").tag(Category?.none)
                    ForEach(categories) { Text($0.name).tag(Optional($0)) }
                }
                LabeledContent("Due date") { DueDateField(date: $due) }
                    // Keep the separator at the row edge rather than under the chip's text.
                    .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
                LabeledContent("Estimate") {
                    HStack(spacing: 8) {
                        Text(estimate == 0 ? "None" : compactHours(estimate)).font(.rounded(13, .bold)).monospacedDigit()
                            .foregroundStyle(estimate == 0 ? DD.ink3 : DD.ink)
                        Stepper("Estimate", value: $estimate, in: 0...(8 * 60), step: 15).labelsHidden()
                    }
                }
            }
            Section { TextField("Notes", text: $notes, axis: .vertical).lineLimit(3...8) }
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard let task else {
            guard let prefill else {
                project = projects.first
                return
            }
            // Unmatched project stays nil so the user must choose; nothing is guessed.
            title = prefill.title
            project = prefill.project
            category = prefill.category
            due = prefill.dueDate
            estimate = prefill.estimateMinutes ?? 0
            return
        }
        title = task.title
        notes = task.notes
        project = task.project
        category = task.category
        due = task.dueDate
        estimate = task.estimateMinutes ?? 0
    }

    private func save() {
        let t = task ?? TaskItem(title: "", project: nil)
        t.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        t.notes = notes
        t.project = project
        t.category = category
        t.dueDate = due.map { Calendar.current.startOfDay(for: $0) }
        t.estimateMinutes = estimate > 0 ? estimate : nil
        if task == nil { context.insert(t) }
    }
}
