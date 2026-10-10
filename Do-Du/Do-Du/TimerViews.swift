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

/// Mini timer above the tab bar: pulsing dot, title, clock, Stop. Tap opens Today.
struct TimerAccessory: View {
    let entry: TimeEntry
    let open: () -> Void
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dim = false

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(DD.mint).frame(width: 8, height: 8).opacity(dim ? 0.35 : 1)
            Text(entry.title).font(.subheadline.weight(.semibold)).foregroundStyle(DD.ink).lineLimit(1)
            Spacer(minLength: 4)
            ElapsedText(start: entry.start).font(.rounded(17, .semibold)).foregroundStyle(DD.forest)
            Button { TimerService.stop(in: context) } label: {
                RoundedRectangle(cornerRadius: 2.5, style: .continuous).fill(.white)
                    .frame(width: 11, height: 11)
                    .frame(width: 40, height: 40)
                    .background(DD.forestFill, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Stop timer")
        }
        .padding(.leading, 18).padding(.trailing, 6)
        .contentShape(Rectangle())
        .onTapGesture(perform: open)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens Today")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { dim = true }
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

    // Keep the status-item label a single static symbol. A ticking HStack (icon +
    // TimelineView text) here froze the app at launch while AppKit sized the status item.
    // The live elapsed time lives in the menu bar panel instead.
    var body: some View {
        Image(systemName: running.isEmpty ? "checklist" : "timer")
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
