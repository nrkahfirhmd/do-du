//
//  TimerViews.swift
//  Do-Du
//

import SwiftUI
import SwiftData

/// Play/stop toggle for one task.
struct TimerButton: View {
    let task: TaskItem
    @Environment(\.modelContext) private var context

    var body: some View {
        let running = task.isRunning
        Button {
            TimerService.toggle(task, in: context)
        } label: {
            Image(systemName: running ? "stop.circle.fill" : "play.circle")
                .imageScale(.large)
                .foregroundStyle(running ? Color.red : Color.accentColor)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(running ? "Stop timer" : "Start timer")
    }
}

/// Start a timer without a task. Tap = no project; the menu picks one.
struct QuickStartButton: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Project> { !$0.isArchived }, sort: \Project.createdAt) private var projects: [Project]

    var body: some View {
        Menu {
            ForEach(projects) { p in
                Button(p.name) { TimerService.start(nil, project: p, in: context) }
            }
        } label: {
            Label("Start Timer", systemImage: "play.fill")
                .frame(maxWidth: .infinity)
        } primaryAction: {
            TimerService.start(nil, in: context)
        }
        .menuStyle(.button)
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .accessibilityHint("Starts a timer without a task. Hold or use the menu to pick a project.")
    }
}

/// Lets a task-less entry pick (or change) its project.
struct ProjectAssignMenu: View {
    let entry: TimeEntry
    @Query(filter: #Predicate<Project> { !$0.isArchived }, sort: \Project.createdAt) private var projects: [Project]

    var body: some View {
        Menu {
            Button("No project") { entry.project = nil }
            ForEach(projects) { p in Button(p.name) { entry.project = p } }
        } label: {
            if let p = entry.project {
                Label { Text(p.name) } icon: { ColorDot(color: p.color) }
            } else {
                Label("Add project", systemImage: "folder.badge.plus")
            }
        }
        .labelStyle(.titleAndIcon)
        .buttonStyle(.borderless)
        .font(.caption)
    }
}

/// Live "1:02:03" for a start date.
struct ElapsedText: View {
    let start: Date
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            Text(ctx.date.timeIntervalSince(start).clock).monospacedDigit()
        }
    }
}

/// Banner for the running timer, shown on Today and in the menu bar.
struct RunningTimerBar: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<TimeEntry> { $0.end == nil }, sort: \TimeEntry.start, order: .reverse)
    private var running: [TimeEntry]

    var body: some View {
        if let entry = running.first {
            HStack {
                Image(systemName: "timer").foregroundStyle(.red)
                VStack(alignment: .leading) {
                    Text(entry.title).lineLimit(1)
                    if entry.task == nil {
                        ProjectAssignMenu(entry: entry)
                    } else if let p = entry.effectiveProject {
                        Text(p.name).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                ElapsedText(start: entry.start).font(.title3)
                Button("Stop", systemImage: "stop.fill") { TimerService.stop(in: context) }
                    .labelStyle(.iconOnly)
                    .tint(.red)
                    .buttonStyle(.borderedProminent)
            }
        } else {
            QuickStartButton()
        }
    }
}

extension TaskItem {
    var isRunning: Bool { entries?.contains(where: \.isRunning) ?? false }
}

#if os(macOS)
struct MenuBarLabel: View {
    @Query(filter: #Predicate<TimeEntry> { $0.end == nil }, sort: \TimeEntry.start, order: .reverse)
    private var running: [TimeEntry]

    var body: some View {
        if let entry = running.first {
            HStack(spacing: 4) {
                Image(systemName: "timer")
                ElapsedText(start: entry.start)
            }
        } else {
            Image(systemName: "checklist")
        }
    }
}

struct MenuBarPanel: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TimeEntry.start, order: .reverse) private var entries: [TimeEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RunningTimerBar()
            Text("Recent").font(.caption).foregroundStyle(.secondary)
            if recentTasks.isEmpty {
                Text("No tracked tasks yet").foregroundStyle(.secondary)
            }
            ForEach(recentTasks) { task in
                HStack {
                    TimerButton(task: task)
                    Text(task.title).lineLimit(1)
                    Spacer()
                    if let p = task.project { ColorDot(color: p.color) }
                }
            }
            Divider()
            HStack {
                Button("Open Do-Du") { NSApp.activate() }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        .padding()
        .frame(width: 300)
    }

    /// Last five distinct open tasks that had time tracked.
    private var recentTasks: [TaskItem] {
        var seen = Set<PersistentIdentifier>()
        return entries.lazy.compactMap(\.task)
            .filter { !$0.isDone && seen.insert($0.persistentModelID).inserted }
            .prefix(5)
            .map { $0 }
    }
}
#endif
