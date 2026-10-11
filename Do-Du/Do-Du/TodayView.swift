//
//  TodayView.swift
//  Do-Du
//
//  Record screen: the timer is the hero, the verdict supports it below.
//

import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Project> { !$0.isArchived }, sort: \Project.createdAt) private var projects: [Project]
    @Query(filter: #Predicate<TaskItem> { !$0.isDone && $0.dueDate != nil }, sort: \TaskItem.dueDate)
    private var dueTasks: [TaskItem]
    @Query(filter: #Predicate<TimeEntry> { $0.end == nil }, sort: \TimeEntry.start, order: .reverse)
    private var running: [TimeEntry]
    /// Entries from the last two days: enough for today's totals and the session strip.
    @Query private var recent: [TimeEntry]
    @State private var quickProject: Project?
    @State private var showUnassigned = false
    @State private var showSettings = false
    @State private var planning = false
    @State private var meetings: [DayEvent] = []

    init() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -2, to: .now)!
        _recent = Query(filter: #Predicate<TimeEntry> { $0.end == nil || $0.start > cutoff }, sort: \TimeEntry.start)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let now = timeline.date
            let day = DayMath.day(now)
            let active = projects.filter { $0.isActive(on: now) }
            ScrollView {
                VStack(spacing: 0) {
                    #if !os(macOS)
                    navRow
                    #endif
                    TimerHero(running: running.first, quickProject: $quickProject, projects: active,
                              recent: recent, now: now) { planning = true }
                        .padding(.horizontal, 12)

                    VerdictStrip(verdict: Stats.verdict(for: projects, on: now, now: now),
                                 progress: overallProgress(active, day: day, now: now))
                        .padding(.horizontal, 12).padding(.top, 10)

                    if !active.isEmpty {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            ForEach(active) { ProjectTile(project: $0, tracked: $0.tracked(in: day, now: now)) }
                        }
                        .padding(.horizontal, 12).padding(.top, 10)
                    }

                    looseGroup(active: active, day: day, now: now)

                    PlanSection(now: now)
                    if !meetings.isEmpty { scheduleGroup }
                    if SharedStore.iCloudOnAtLaunch, FileManager.default.ubiquityIdentityToken == nil {
                        ICloudStatus().font(.footnote).foregroundStyle(DD.ink3)
                            .padding(.horizontal, 32).padding(.top, 16)
                    }
                    let due = dueTasks.filter { $0.dueDate! <= DayMath.logicalDate(now) && $0.project?.isArchived == false }
                    if !due.isEmpty {
                        SectionHeader("Due today")
                        DDGroup { ForEach(due) { TaskRow(task: $0).padding(.horizontal, 16).frame(minHeight: 52) } }
                    }
                }
                .padding(.bottom, 24)
            }
            .background(DD.page)
        }
        .navigationTitle("Today")
        #if !os(macOS)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsView().toolbar { Button("Done") { showSettings = false } } }
        }
        #else
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Plan My Day", systemImage: "sparkles") { planning = true }
            }
        }
        #endif
        .task { meetings = await CalendarAccess.todayEvents() }
        .sheet(isPresented: $showUnassigned) { UnassignedEntriesView() }
        .sheet(isPresented: $planning) { PlanSheet() }
    }

    // MARK: Pieces

    #if !os(macOS)
    private var navRow: some View {
        HStack {
            Text("Today").font(.ddTitle2).foregroundStyle(DD.forest)
            Spacer()
            if OnboardingGate.justFinished { SetUpChip() }
            DDIconButton(systemImage: "sparkles", label: "Plan My Day") { planning = true }
            DDIconButton(systemImage: "gearshape", label: "Settings") { showSettings = true }
        }
        .frame(height: 52)
        .padding(.horizontal, 20)
    }
    #endif

    @ViewBuilder
    private func looseGroup(active: [Project], day: DateInterval, now: Date) -> some View {
        let loose = recent.filter { $0.effectiveProject == nil }
        let looseTime = loose.tracked(in: day, now: now)
        if active.isEmpty || looseTime > 0 {
            DDGroup(radius: DD.Radius.card, inset: 12) {
                if active.isEmpty {
                    Text("No projects scheduled today. Tracked time still counts.")
                        .font(.subheadline).foregroundStyle(DD.ink3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16).padding(.vertical, 14)
                }
                if looseTime > 0 {
                    Menu {
                        Section("Assign \(looseTime.hoursMinutes) to") {
                            ForEach(active) { p in Button(p.name) { assignLoose(to: p, day: day) } }
                        }
                        Button("Edit Sessions…", systemImage: "pencil") { showUnassigned = true }
                    } label: {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(DD.ink3, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                                .frame(width: 12, height: 12)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("No project").font(.body).foregroundStyle(DD.ink)
                                Text("Not counted toward targets. Tap to assign.").font(.footnote).foregroundStyle(DD.ink3)
                            }
                            Spacer()
                            Text(looseTime.hoursMinutes).font(.rounded(16, .medium)).monospacedDigit().foregroundStyle(DD.ink3)
                            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(DD.ink3.opacity(0.6))
                        }
                        .padding(.horizontal, 16).frame(minHeight: 60)
                        .contentShape(Rectangle())
                    }
                    .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden)
                }
            }
            .padding(.top, 10)
        }
    }

    private var scheduleGroup: some View {
        VStack(spacing: 0) {
            SectionHeader("Schedule")
            DDGroup {
                ForEach(Array(meetings.enumerated()), id: \.offset) { _, m in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(m.title).lineLimit(1).foregroundStyle(DD.ink)
                        Text("\(m.start.formatted(date: .omitted, time: .shortened)) – \(m.end.formatted(date: .omitted, time: .shortened))")
                            .font(.footnote).foregroundStyle(DD.ink3)
                    }
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: Data

    /// Share of today's targets covered (0…1).
    private func overallProgress(_ active: [Project], day: DateInterval, now: Date) -> Double {
        let total = active.reduce(0) { $0 + $1.dailyTarget }
        guard total > 0 else { return 0 }
        let covered = active.reduce(0) { $0 + min($1.dailyTarget, $1.tracked(in: day, now: now)) }
        return covered / total
    }

    /// Moves today's finished No-project sessions onto `project`.
    private func assignLoose(to project: Project, day: DateInterval) {
        for e in recent where e.effectiveProject == nil && e.start < day.end && (e.end ?? .now) > day.start {
            e.project = project
        }
        try? context.save()
    }
}

/// Ring + one sentence with the key value on a mint tag.
struct VerdictStrip: View {
    let verdict: Verdict
    let progress: Double
    var font: Font = .ddHeadlineRounded

    var body: some View {
        HStack(spacing: 14) {
            ProgressRing(value: verdict == .enough ? 1 : progress, size: 46, thickness: 6,
                         color: verdict == .enough ? DD.mint : DD.forest)
            sentence.font(font).foregroundStyle(DD.forest).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18).padding(.vertical, 16)
        .background(DD.surface, in: .dd(28))
        .accessibilityElement(children: .combine)
    }

    private var sentence: Text {
        switch verdict {
        case .notYet(let left): highlighted("You need ", left.hoursMinutes, " more to call it a day.")
        case .enough: highlighted("You’ve done ", "enough", ". Stopping is allowed.")
        case .restDay: highlighted("Rest day. ", "Nothing", " is scheduled.")
        }
    }
}

/// Today's progress for one project. Turns mint when the target is met.
struct ProjectTile: View {
    let project: Project
    let tracked: TimeInterval
    var ringSize: CGFloat = 104

    var body: some View {
        let target = project.dailyTarget
        let value = target > 0 ? tracked / target : 1
        let met = value >= 1
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(project.name).font(.ddHeadlineRounded).lineLimit(1)
                Spacer(minLength: 8)
                // Small (Mac) tiles only flag DONE; there is no room for "… left".
                if met || ringSize >= 90 {
                    Text(met ? "DONE ✓" : "\(max(0, target - tracked).hoursMinutes) left").font(.rounded(13, .heavy)).lineLimit(1)
                }
            }
            ProgressRing(value: value, size: ringSize, thickness: ringSize * 0.115,
                         color: met ? DD.onMint : ringColor,
                         track: met ? DD.onMint.opacity(0.15) : DD.track) {
                Text("\(Int(min(1, value) * 100))%").font(ringSize >= 90 ? .ddStat : .rounded(15)).tracking(-0.5).monospacedDigit()
            }
            Text("\(tracked.hoursMinutes) of \(target.hoursMinutes)")
                .font(.rounded(14, .semibold)).monospacedDigit().opacity(0.75).lineLimit(1)
        }
        .foregroundStyle(met ? DD.onMint : DD.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EdgeInsets(top: 16, leading: 16, bottom: 18, trailing: 16))
        .background(met ? DD.mint : DD.surface, in: .dd(DD.Radius.tile))
        .animation(DD.colorChange, value: met)
        .sensoryFeedback(.success, trigger: met) { was, now in !was && now }
    }

    /// Very light swatches read poorly as a ring; the handoff swaps them for pine.
    private var ringColor: Color {
        Palette.canonical(project.colorName) == "seafoam" ? Palette.color("pine") : project.color
    }
}

/// Inset grouped container (surface, radius 20) with hairline separators.
struct DDGroup<Content: View>: View {
    var radius: CGFloat = DD.Radius.group
    var inset: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            Group(subviews: content) { subviews in
                ForEach(Array(subviews.enumerated()), id: \.offset) { i, sub in
                    sub
                    if i < subviews.count - 1 {
                        Rectangle().fill(DD.separator).frame(height: 0.5).padding(.leading, 16)
                    }
                }
            }
        }
        .background(DD.surface, in: .dd(radius))
        .padding(.horizontal, inset)
    }
}

/// Section header: 13 semibold, sentence case, Ink 3, inset 32.
struct SectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title).font(.footnote.weight(.semibold)).foregroundStyle(DD.ink3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32).padding(.top, 26).padding(.bottom, 6)
    }
}

#Preview {
    NavigationStack { TodayView() }
        .modelContainer(SharedStore.preview)
}
