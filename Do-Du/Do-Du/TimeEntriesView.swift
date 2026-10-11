//
//  TimeEntriesView.swift
//  Do-Du
//

import SwiftUI
import SwiftData

struct TimeEntriesView: View {
    let task: TaskItem
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var editing: TimeEntry?
    @State private var creating = false

    var body: some View {
        NavigationStack {
            List {
                Group {
                    let entries = (task.entries ?? []).sorted { $0.start > $1.start }
                    if entries.isEmpty {
                        Text("No time tracked yet.").foregroundStyle(.secondary)
                    }
                    ForEach(entries) { entry in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(entry.start.formatted(date: .abbreviated, time: .omitted))
                                Text(range(entry)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if entry.isRunning {
                                ElapsedText(start: entry.start).foregroundStyle(.red)
                            } else {
                                Text(entry.duration().hoursMinutes).monospacedDigit()
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { editing = entry }
                        .contextMenu {
                            Button("Edit") { editing = entry }
                            Button("Delete", role: .destructive) { context.delete(entry) }
                        }
                        .swipeActions { Button("Delete", role: .destructive) { context.delete(entry) } }
                    }
                            }
                .ddRows()
            }
            .ddForm()
            .navigationTitle(task.title)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                ToolbarItem { Button("Add Time", systemImage: "plus") { creating = true } }
            }
            .sheet(isPresented: $creating) { EntryEditor(task: task, entry: nil) }
            .sheet(item: $editing) { EntryEditor(task: task, entry: $0) }
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 360)
        #endif
    }

    private func range(_ e: TimeEntry) -> String {
        let start = e.start.formatted(date: .omitted, time: .shortened)
        return e.end.map { "\(start) – \($0.formatted(date: .omitted, time: .shortened))" } ?? "\(start) – now"
    }
}

struct EntryEditor: View {
    /// Nil when editing a quick-timer entry.
    let task: TaskItem?
    let entry: TimeEntry?
    @Environment(\.modelContext) private var context
    // ponytail: loads every entry for overlap checks; fine for one person's history, use a date-bounded predicate if it grows huge.
    @Query private var allEntries: [TimeEntry]
    @State private var start = Date.now.addingTimeInterval(-3600)
    @State private var end = Date.now

    private var isRunning: Bool { entry?.isRunning ?? false }

    var body: some View {
        EditorSheet(title: entry == nil ? "Add Time" : "Edit Time", canSave: problem == nil, save: save) {
            DatePicker("Start", selection: $start)
            if isRunning {
                LabeledContent("End", value: "Running")
            } else {
                DatePicker("End", selection: $end)
            }
            if let problem {
                Label(problem, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
            } else {
                LabeledContent("Duration", value: (isRunning ? Date.now : end).timeIntervalSince(start).hoursMinutes)
            }
        }
        .onAppear {
            guard let entry else { return }
            start = entry.start
            end = entry.end ?? .now
        }
    }

    /// Why the current values can't be saved, or nil if they can.
    private var problem: String? {
        let now = Date.now
        let effectiveEnd = isRunning ? now : end
        if start >= effectiveEnd { return "End must be after start." }
        if effectiveEnd > now.addingTimeInterval(60) { return "Can't log time in the future." }
        let others = allEntries.filter { $0 != entry }
        if let i = DayMath.firstConflict(start: start, end: effectiveEnd,
                                         in: others.map { ($0.start, $0.end ?? now) }) {
            let o = others[i]
            let t = { (d: Date) in d.formatted(date: .abbreviated, time: .shortened) }
            return "Overlaps \"\(o.title)\" (\(t(o.start)) – \(o.end.map(t) ?? "now"))."
        }
        return nil
    }

    private func save() {
        let e = entry ?? TimeEntry(task: task, start: start, end: end)
        e.start = start
        if !isRunning { e.end = end }
        if entry == nil { context.insert(e) }
    }
}

/// Quick-timer entries with no project yet. Assigning a project moves them out of this list.
struct UnassignedEntriesView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<TimeEntry> { $0.task == nil && $0.project == nil }, sort: \TimeEntry.start, order: .reverse)
    private var entries: [TimeEntry]
    @State private var editing: TimeEntry?

    var body: some View {
        NavigationStack {
            List {
                Group {
                    if entries.isEmpty { Text("All time is assigned.").foregroundStyle(.secondary) }
                    ForEach(entries) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.start.formatted(date: .abbreviated, time: .shortened))
                                ProjectAssignMenu(entry: entry)
                            }
                            Spacer()
                            if entry.isRunning {
                                ElapsedText(start: entry.start).foregroundStyle(.red)
                            } else {
                                Text(entry.duration().hoursMinutes).monospacedDigit()
                            }
                        }
                        .contextMenu {
                            Button("Edit Time") { editing = entry }
                            Button("Delete", role: .destructive) { context.delete(entry) }
                        }
                        .swipeActions {
                            Button("Delete", role: .destructive) { context.delete(entry) }
                            Button("Edit") { editing = entry }
                        }
                    }
                            }
                .ddRows()
            }
            .ddForm()
            .navigationTitle("No Project")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $editing) { EntryEditor(task: nil, entry: $0) }
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 360)
        #endif
    }
}
