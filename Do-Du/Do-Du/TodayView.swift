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

    var body: some View {
        // ponytail: recomputes all of today's totals every 5s; cache per-day totals if history gets large.
        TimelineView(.periodic(from: .now, by: 5)) { timeline in
            let now = timeline.date
            let day = DayMath.day(now)
            let active = projects.filter { $0.isActive(on: now) }
            List {
                Section { RunningTimerBar() }
                Section { VerdictBanner(verdict: Stats.verdict(for: projects, on: now, now: now)) }
                if !active.isEmpty {
                    Section("Projects") {
                        ForEach(active) { ProjectProgressRow(project: $0, tracked: $0.tracked(in: day, now: now)) }
                    }
                }
                let due = dueTasks.filter { $0.dueDate! < day.end && $0.project?.isArchived == false }
                if !due.isEmpty {
                    Section("Due today") {
                        ForEach(due) { TaskRow(task: $0) }
                    }
                }
            }
        }
        .navigationTitle("Today")
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
