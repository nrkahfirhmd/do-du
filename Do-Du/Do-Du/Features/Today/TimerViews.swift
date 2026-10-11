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
            Group {
                if running {
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous).fill(.white).frame(width: 11, height: 11)
                } else {
                    Image(systemName: "play.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(DD.forest)
                        .offset(x: 1)
                }
            }
            .frame(width: 36, height: 36)
            .background(running ? DD.forestFill : DD.fill, in: Circle())
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(running ? "Stop timer" : "Start timer")
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

/// Menu-bar panel: hero card (forest while recording), verdict line, Recent tasks, footer.
struct MenuBarPanel: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TimeEntry.start, order: .reverse) private var entries: [TimeEntry]
    @Query(filter: #Predicate<Project> { !$0.isArchived }, sort: \Project.createdAt) private var projects: [Project]

    var body: some View {
        let running = entries.first(where: \.isRunning)
        TimelineView(.periodic(from: .now, by: 1)) { tl in
            VStack(alignment: .leading, spacing: 12) {
                hero(running, now: tl.date)
                VerdictStrip(verdict: Stats.verdict(for: projects, on: tl.date, now: tl.date),
                             progress: 0, font: .rounded(15, .bold))
                    .padding(-4)
                Text("Recent").font(.footnote.weight(.semibold)).foregroundStyle(DD.ink3)
                if recentTasks.isEmpty {
                    Text("No tracked tasks yet").font(.subheadline).foregroundStyle(DD.ink3)
                }
                VStack(spacing: 2) {
                    ForEach(recentTasks) { task in
                        Button { TimerService.toggle(task, in: context) } label: {
                            HStack(spacing: 10) {
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(task.project?.color ?? DD.disabled).frame(width: 10, height: 10)
                                Text(task.title).lineLimit(1).foregroundStyle(DD.ink)
                                Spacer()
                                Image(systemName: task.isRunning ? "stop.fill" : "play.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(task.isRunning ? DD.onMint : DD.forest)
                            }
                            .padding(.horizontal, 10).frame(height: 32)
                            .background(task.isRunning ? DD.mint : .clear, in: .dd(8))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                Divider()
                HStack {
                    Button("Open Do-Du") { NSApp.activate() }
                    Spacer()
                    Button("Quit") { NSApp.terminate(nil) }
                }
                .buttonStyle(.borderless)
                .tint(DD.sage)
            }
            .padding(14)
        }
        .frame(width: 300)
    }

    private func hero(_ running: TimeEntry?, now: Date) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(running?.title ?? "No timer running").font(.subheadline.weight(.semibold)).lineLimit(1).opacity(0.8)
                Text((running.map { now.timeIntervalSince($0.start) } ?? 0).clock)
                    .font(.rounded(40)).tracking(-1).monospacedDigit()
            }
            Spacer(minLength: 0)
            Button {
                TimerService.toggleQuick(in: context)
            } label: {
                Group {
                    if running != nil {
                        RoundedRectangle(cornerRadius: 4, style: .continuous).fill(DD.onMint).frame(width: 14, height: 14)
                    } else {
                        Image(systemName: "play.fill").font(.system(size: 16, weight: .bold)).foregroundStyle(DD.mint)
                    }
                }
                .frame(width: 44, height: 44)
                .background(running != nil ? DD.mint : DD.forestFill, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(running != nil ? "Stop timer" : "Start timer")
        }
        .foregroundStyle(running != nil ? Color.white : DD.ink)
        .padding(14)
        .background(running != nil ? DD.forestFill : DD.fill, in: .dd(DD.Radius.menu))
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
