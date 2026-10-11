//
//  MacViews.swift
//  Do-Du
//
//  Mac main window from the redesign: sidebar (sections, projects with today's %,
//  mini timer card) and a two-column Today. Other sections reuse the shared views.
//

#if os(macOS)
import SwiftUI
import SwiftData

struct MacRootView: View {
    @Environment(\.modelContext) private var context
    @State private var section = AppTab.today
    @State private var quickAdd = false
    @State private var planning = false

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
                        Button("Quick Add ⌘K", systemImage: "sparkles") { quickAdd = true }
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
            section = .today
        }
        .sheet(isPresented: $quickAdd) { QuickAddSheet() }
        .sheet(isPresented: $planning) { PlanSheet() }
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

/// Sidebar footer: running timer (forest, mint Stop) or idle start.
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

/// Today on Mac: hero on the left; verdict, tiles, sessions and No project on the right.
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
            // Two columns at 1.15fr / 1fr with a 16pt gap inside 28pt side padding.
            let usable = max(0, geo.size.width - 56 - 16)
            ScrollView {
                HStack(alignment: .top, spacing: 16) {
                    TimerHero(running: running.first, quickProject: $quickProject, projects: active,
                              recent: recent, now: now, clockFont: .ddClockMac) { planning = true }
                        .frame(width: usable * 1.15 / 2.15)
                    VStack(spacing: 12) {
                        VerdictStrip(verdict: Stats.verdict(for: projects, on: now, now: now),
                                     progress: progress(active, day: day, now: now), font: .rounded(30))
                        if !active.isEmpty {
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                                ForEach(active) { ProjectTile(project: $0, tracked: $0.tracked(in: day, now: now), ringSize: 72) }
                            }
                        }
                        sessions(day: day, now: now)
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
                        Text("\(e.start.formatted(date: .omitted, time: .shortened))–\(e.end?.formatted(date: .omitted, time: .shortened) ?? "now")")
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
