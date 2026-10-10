//
//  TodayView.swift
//  Do-Du
//

import SwiftUI
import SwiftData

struct TodayView: View {
    @Query(filter: #Predicate<Project> { !$0.isArchived }, sort: \Project.createdAt) private var projects: [Project]
    @Query(filter: #Predicate<TaskItem> { !$0.isDone && $0.dueDate != nil }, sort: \TaskItem.dueDate)
    private var dueTasks: [TaskItem]
    @Query(filter: #Predicate<TimeEntry> { $0.task == nil && $0.project == nil }) private var unassigned: [TimeEntry]
    @State private var showUnassigned = false
    @State private var showSettings = false
    @State private var planning = false
    @State private var meetings: [DayEvent] = []

    var body: some View {
        // ponytail: recomputes all of today's totals every 5s; cache per-day totals if history gets large.
        TimelineView(.periodic(from: .now, by: 5)) { timeline in
            let now = timeline.date
            let day = DayMath.day(now)
            let active = projects.filter { $0.isActive(on: now) }
            List {
                Section { RunningTimerBar() }
                Section { VerdictBanner(verdict: Stats.verdict(for: projects, on: now, now: now)) }
                PlanSection(now: now)
                if !meetings.isEmpty {
                    Section("Schedule") {
                        ForEach(Array(meetings.enumerated()), id: \.offset) { _, m in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m.title).lineLimit(1)
                                Text("\(m.start.formatted(date: .omitted, time: .shortened)) – \(m.end.formatted(date: .omitted, time: .shortened))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                if !active.isEmpty {
                    Section("Projects") {
                        ForEach(active) { ProjectProgressRow(project: $0, tracked: $0.tracked(in: day, now: now)) }
                    }
                }
                let loose = unassigned.tracked(in: day, now: now)
                if loose > 0 {
                    Section {
                        Button { showUnassigned = true } label: {
                            HStack {
                                Label {
                                    Text("No project")
                                    Text("Not counted toward targets. Tap to assign.")
                                } icon: {
                                    Image(systemName: "questionmark.folder")
                                }
                                Spacer()
                                Text(loose.hoursMinutes).monospacedDigit().foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                if FileManager.default.ubiquityIdentityToken == nil {
                    Section { ICloudStatus().font(.footnote) }
                }
                let due = dueTasks.filter { $0.dueDate! <= DayMath.logicalDate(now) && $0.project?.isArchived == false }
                if !due.isEmpty {
                    Section("Due today") {
                        ForEach(due) { TaskRow(task: $0) }
                    }
                }
            }
        }
        .navigationTitle("Today")
        .task { meetings = await CalendarAccess.todayEvents() }
        .sheet(isPresented: $showUnassigned) { UnassignedEntriesView() }
        .sheet(isPresented: $planning) { PlanSheet() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Plan My Day", systemImage: "sparkles") { planning = true }
            }
        }
        #if !os(macOS)
        // iPhone keeps five tabs; Settings lives here. macOS uses the Settings window.
        .toolbar { Button("Settings", systemImage: "gear") { showSettings = true } }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView().toolbar { Button("Done") { showSettings = false } }
            }
        }
        #endif
    }
}

struct VerdictBanner: View {
    let verdict: Verdict

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title2.bold())
                Text(subtitle).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private var icon: String {
        switch verdict {
        case .enough: "checkmark.seal.fill"
        case .restDay: "cup.and.saucer.fill"
        case .notYet: "hourglass"
        }
    }

    private var tint: Color {
        switch verdict {
        case .enough: .green
        case .restDay: .teal
        case .notYet: .orange
        }
    }

    private var title: String {
        switch verdict {
        case .enough: "You've done enough today"
        case .restDay: "Rest day"
        case .notYet: "Not yet"
        }
    }

    private var subtitle: String {
        switch verdict {
        case .enough: "Every project hit its target. Stopping is allowed."
        case .restDay: "No projects scheduled today."
        case .notYet(let remaining): "\(remaining.hoursMinutes) left across your projects."
        }
    }
}

struct ProjectProgressRow: View {
    let project: Project
    let tracked: TimeInterval

    var body: some View {
        let target = project.dailyTarget
        let met = tracked >= target
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                ColorDot(color: project.color)
                Text(project.name)
                Spacer()
                if met { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                Text("\(tracked.hoursMinutes) / \(target.hoursMinutes)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: target > 0 ? min(1, tracked / target) : 1)
                .tint(project.color)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack { TodayView() }
        .modelContainer(for: allModels, inMemory: true)
}
