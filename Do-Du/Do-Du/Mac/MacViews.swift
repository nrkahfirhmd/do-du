#if os(macOS)
import SwiftUI
import SwiftData

struct MacRootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openSettings) private var openSettings
    @State private var section = AppTab.today
    @State private var planning = false
    #if DEBUG
    @State private var debugTask: TaskItem?
    @State private var debugProject = false
    #endif

    var body: some View {
        NavigationSplitView {
            MacSidebar(selection: $section)
                .navigationSplitViewColumnWidth(min: 210, ideal: 230, max: 280)
        } detail: {
            NavigationStack {
                Group {
                    switch section {
                    case .today: MacTodayView()
                    case .tasks: TasksView()
                    case .assistant: AssistantView()
                    case .stats: StatsView()
                    case .projects: ProjectsView()
                    }
                }
                .tint(DD.sage)
                .navigationTitle(title)
                .navigationSubtitle(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .toolbar {
                    if OnboardingGate.justFinished && section == .today {
                        ToolbarItem(placement: .navigation) { SetUpChip() }
                    }
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button("Quick Add ⌘K", systemImage: "sparkles") { QuickAddPanel.show() }
                            .labelStyle(.titleAndIcon)
                            .keyboardShortcut("k")
                        Button("Plan My Day", systemImage: "sparkles") { planning = true }
                            .labelStyle(.titleAndIcon)
                            .ddPrimary()
                    }
                }
            }
        }
        .tint(DD.forestFill)
        .frame(minWidth: 1000, minHeight: 640)
        .onOpenURL { url in
            if url.host() == "timer" && url.path() == "/toggle" { TimerService.toggleQuick(in: context) }
            section = url.host() == "tasks" ? .tasks : .today
        }
        .sheet(isPresented: $planning) { PlanSheet() }
        #if DEBUG
        // DEBUG review hooks: -macSection, -openSettings, -macSettingsTab, -macSheet, -quickAddText.
        .task {
            let d = UserDefaults.standard
            if d.bool(forKey: "openSettings") { openSettings() }
            if let name = d.string(forKey: "macSection"),
                let tab = [AppTab.today, .tasks, .assistant, .stats, .projects].first(where: { "\($0)" == name })
            {
                section = tab
            }
            switch d.string(forKey: "macSheet") {
            case "quick": QuickAddPanel.show(text: d.string(forKey: "quickAddText") ?? "")
            case "plan": planning = true
            case "task": debugTask = (try? context.fetch(FetchDescriptor<TaskItem>()))?.first
            case "project": debugProject = true
            default: break
            }
        }
        .sheet(item: $debugTask) { TaskEditor(task: $0) }
        .sheet(isPresented: $debugProject) {
            ProjectEditor(project: (try? context.fetch(FetchDescriptor<Project>()))?.first)
        }
        #endif
    }

    private var title: String {
        switch section {
        case .today: "Today"
        case .tasks: "Tasks"
        case .assistant: "Assistant"
        case .stats: "Stats"
        case .projects: "Projects"
        }
    }
}

struct MacSidebar: View {
    @Binding var selection: AppTab
    @Query(filter: #Predicate<Project> { !$0.isArchived }, sort: \Project.createdAt) private var projects: [Project]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { tl in
            List(selection: $selection) {
                Section {
                    row("Today", "sun.max", .today)
                    row("Tasks", "checklist", .tasks)
                    row("Assistant", "sparkles", .assistant)
                    row("Stats", "chart.bar", .stats)
                    row("Projects", "folder", .projects)
                }
                Section("Projects") {
                    ForEach(projects) { p in
                        let day = DayMath.day(tl.date)
                        let pct = p.dailyTarget > 0 ? min(1, p.tracked(in: day, now: tl.date) / p.dailyTarget) : 1
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 3, style: .continuous).fill(p.color).frame(width: 10, height: 10)
                            Text(p.name).lineLimit(1)
                            Spacer()
                            Text("\(Int(pct * 100))%").font(.rounded(12, .semibold)).monospacedDigit()
                                .foregroundStyle(pct >= 1 ? DD.sage : DD.ink3)
                        }
                        .selectionDisabled()
                    }
                }
            }
            .listStyle(.sidebar)
        }
        .safeAreaInset(edge: .bottom) { MacMiniTimer().padding(12) }
    }

    private func row(_ title: String, _ icon: String, _ tab: AppTab) -> some View {
        Label(title, systemImage: icon).tag(tab).frame(height: 30)
    }
}

struct MacMiniTimer: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<TimeEntry> { $0.end == nil }, sort: \TimeEntry.start, order: .reverse)
    private var running: [TimeEntry]

    var body: some View {
        let entry = running.first
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry?.title ?? "No timer running").font(.caption.weight(.semibold)).lineLimit(1).opacity(0.8)
                if let entry {
                    ElapsedText(start: entry.start).font(.rounded(22))
                } else {
                    Text("0:00:00").font(.rounded(22)).monospacedDigit()
                }
            }
            Spacer(minLength: 0)
            Button {
                TimerService.toggleQuick(in: context)
            } label: {
                Group {
                    if entry != nil {
                        RoundedRectangle(cornerRadius: 3, style: .continuous).fill(DD.onMint).frame(width: 12, height: 12)
                    } else {
                        Image(systemName: "play.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(DD.mint)
                    }
                }
                .frame(width: 36, height: 36)
                .background(entry != nil ? DD.mint : DD.forestFill, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(entry != nil ? "Stop timer" : "Start timer")
        }
        .foregroundStyle(entry != nil ? Color.white : DD.ink)
        .padding(12)
        .background(entry != nil ? DD.forestFill : DD.fill, in: .dd(DD.Radius.card))
        .animation(DD.colorChange, value: entry != nil)
    }
}

struct MacTodayView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Project> { !$0.isArchived }, sort: \Project.createdAt) private var projects: [Project]
    @Query(filter: #Predicate<TimeEntry> { $0.end == nil }, sort: \TimeEntry.start, order: .reverse)
    private var running: [TimeEntry]
    @Query private var recent: [TimeEntry]
    @State private var quickProject: Project?
    @State private var planning = false
    @FocusState private var focused: Bool

    init() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -2, to: .now)!
        _recent = Query(filter: #Predicate<TimeEntry> { $0.end == nil || $0.start > cutoff }, sort: \TimeEntry.start)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { tl in
            let now = tl.date
            let day = DayMath.day(now)
            let active = projects.filter { $0.isActive(on: now) }
            GeometryReader { geo in
                let usable = max(0, geo.size.width - 56 - 16)
                ScrollView {
                    HStack(alignment: .top, spacing: 16) {
                        TimerHero(
                            running: running.first, quickProject: $quickProject, projects: active,
                            recent: recent, now: now, clockFont: .ddClockMac
                        ) { planning = true }
                        .frame(width: usable * 1.15 / 2.15)
                        VStack(spacing: 12) {
                            VerdictStrip(
                                verdict: Stats.verdict(for: projects, on: now, now: now),
                                progress: progress(active, day: day, now: now), font: .rounded(30))
                            if !active.isEmpty {
                                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                                    ForEach(active) { ProjectTile(project: $0, tracked: $0.tracked(in: day, now: now), ringSize: 72) }
                                }
                            }
                            sessions(day: day, now: now)
                            loose(active: active, day: day, now: now)
                        }
                        .frame(width: usable / 2.15)
                    }
                    .padding(EdgeInsets(top: 20, leading: 28, bottom: 28, trailing: 28))
                }
            }
            .background(DD.page)
        }
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onAppear { focused = true }
        // Space starts or stops the timer while Today has focus (never steals spaces from text fields).
        .onKeyPress(.space) {
            TimerService.toggleQuick(project: quickProject, in: context)
            return .handled
        }
        .sheet(isPresented: $planning) { PlanSheet() }
    }

    @ViewBuilder
    private func loose(active: [Project], day: DateInterval, now: Date) -> some View {
        let entries = recent.filter { $0.effectiveProject == nil && $0.start < day.end && ($0.end ?? now) > day.start }
        let time = entries.tracked(in: day, now: now)
        if time > 0 {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(DD.ink3, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                    .frame(width: 10, height: 10)
                Text("\(Text("No project").fontWeight(.semibold))\(Text(" · \(time.hoursMinutes) not counted").foregroundStyle(DD.ink3))")
                    .font(.system(size: 14))
                Spacer()
                Menu("Assign…") {
                    ForEach(active) { p in
                        Button(p.name) {
                            entries.forEach { $0.project = p }
                            try? context.save()
                        }
                    }
                }
                .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden)
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(DD.sage)
                .fixedSize()
                .disabled(active.isEmpty)
            }
            .foregroundStyle(DD.ink)
            .padding(.horizontal, 18).padding(.vertical, 12)
            .background(DD.surface, in: .dd(22))
        }
    }

    private func progress(_ active: [Project], day: DateInterval, now: Date) -> Double {
        let total = active.reduce(0) { $0 + $1.dailyTarget }
        guard total > 0 else { return 0 }
        return active.reduce(0) { $0 + min($1.dailyTarget, $1.tracked(in: day, now: now)) } / total
    }

    @ViewBuilder
    private func sessions(day: DateInterval, now: Date) -> some View {
        let today = recent.filter { $0.start < day.end && ($0.end ?? now) > day.start }.reversed()
        if !today.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("Sessions today").font(.footnote.weight(.semibold)).foregroundStyle(DD.ink3)
                    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 6)
                ForEach(Array(today), id: \.persistentModelID) { e in
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(e.effectiveProject?.color ?? DD.disabled).frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(e.effectiveProject?.name ?? "No project").font(.subheadline.weight(.semibold))
                            Text(e.title).font(.caption).foregroundStyle(e.isRunning ? DD.onMint.opacity(0.7) : DD.ink3)
                        }
                        .lineLimit(1)
                        Spacer()
                        Text(
                            "\(e.start.formatted(date: .omitted, time: .shortened))–\(e.end?.formatted(date: .omitted, time: .shortened) ?? "now")"
                        )
                        .font(.caption).monospacedDigit().foregroundStyle(e.isRunning ? DD.onMint.opacity(0.7) : DD.ink3)
                        Text(e.duration(now: now).hoursMinutes).font(.rounded(14, .semibold)).monospacedDigit()
                            .frame(width: 64, alignment: .trailing)
                    }
                    .foregroundStyle(e.isRunning ? DD.onMint : DD.ink)
                    .padding(.horizontal, 16).frame(minHeight: 44)
                    .background(e.isRunning ? DD.mint : .clear)
                }
            }
            .padding(.bottom, 6)
            .background(DD.surface, in: .dd(DD.Radius.card))
            .clipShape(.dd(DD.Radius.card))
        }
    }
}
#endif

#if os(macOS)
struct MacTaskTable: View {
    let tasks: [TaskItem]
    let edit: (TaskItem) -> Void
    let entries: (TaskItem) -> Void
    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(spacing: 0) {
            row {
                Text("")
            } title: {
                Text("Task")
            } category: {
                Text("Category")
            } due: {
                Text("Due")
            } estimate: {
                Text("Estimate")
            } play: {
                Text("")
            }
            .font(.system(size: 11, weight: .semibold)).foregroundStyle(DD.ink3)
            .frame(height: 30)
            ForEach(tasks) { task in
                Divider()
                let today = DayMath.logicalDate(.now)
                row {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { task.setDone(!task.isDone) }
                    } label: {
                        ZStack {
                            Circle().strokeBorder(task.isDone ? DD.mint : DD.disabled, lineWidth: 2)
                                .background(Circle().fill(task.isDone ? DD.mint : .clear))
                            if task.isDone {
                                Image(systemName: "checkmark").font(.system(size: 9, weight: .black)).foregroundStyle(DD.onMint)
                            }
                        }
                        .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(task.isDone ? "Mark not done" : "Mark done")
                    .sensoryFeedback(.impact(weight: .light), trigger: task.isDone) { _, done in done }
                } title: {
                    Button {
                        edit(task)
                    } label: {
                        Text(task.title).strikethrough(task.isDone).foregroundStyle(task.isDone ? DD.ink3 : DD.ink)
                            .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } category: {
                    if let c = task.category {
                        HStack(spacing: 6) {
                            Circle().fill(c.color).frame(width: 7, height: 7)
                            Text(c.name).lineLimit(1)
                        }
                    }
                } due: {
                    if let due = task.dueDate {
                        Text(dueLabel(due, today: today))
                            .foregroundStyle(due <= today && !task.isDone ? DD.danger : DD.ink3)
                    }
                } estimate: {
                    if let m = task.estimateMinutes { Text(compactHours(m)).monospacedDigit() }
                } play: {
                    if !task.isDone { TimerButton(task: task) }
                }
                .font(.system(size: 14))
                .frame(height: 44)
                .background(task.isRunning ? DD.runningRow : .clear)
                .contextMenu {
                    Button("Edit…") { edit(task) }
                    Button("Time Entries…") { entries(task) }
                    Button("Delete", role: .destructive) { context.delete(task) }
                }
            }
        }
        .background(DD.surface, in: .dd(18))
        .clipShape(.dd(18))
    }

    private func dueLabel(_ due: Date, today: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: today, to: due).day ?? 0
        switch days {
        case 0: return "Today"
        case 1: return "Tomorrow"
        case ..<0: return "Overdue"
        default: return due.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        }
    }

    private func row<A: View, B: View, C: View, D: View, E: View, F: View>(
        @ViewBuilder done: () -> A, @ViewBuilder title: () -> B, @ViewBuilder category: () -> C,
        @ViewBuilder due: () -> D, @ViewBuilder estimate: () -> E, @ViewBuilder play: () -> F
    ) -> some View {
        // Each cell sits on Color.clear so an empty one still takes its column.
        func cell(_ width: CGFloat?, _ alignment: Alignment = .leading, _ content: some View) -> some View {
            ZStack(alignment: alignment) {
                Color.clear
                content
            }
            .frame(width: width).frame(maxWidth: width == nil ? .infinity : nil)
        }
        return HStack(spacing: 0) {
            cell(36, .leading, done())
            cell(nil, .leading, title())
            cell(120, .leading, category())
            cell(100, .leading, due())
            cell(90, .leading, estimate())
            cell(48, .trailing, play())
        }
        .padding(.horizontal, 14)
    }
}
#endif
