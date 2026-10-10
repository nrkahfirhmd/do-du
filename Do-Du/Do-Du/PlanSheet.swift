//
//  PlanSheet.swift
//  Do-Du
//

import SwiftUI
import SwiftData

struct PlanSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Project.createdAt) private var projects: [Project]
    @Query private var entries: [TimeEntry]
    @Query private var tasks: [TaskItem]
    @State private var items: [PlanItem] = []
    @State private var note = ""
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                if loading {
                    ProgressView("Planning your day…")
                } else if let error {
                    Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                    Button("Try Again", action: plan)
                } else {
                    if !note.isEmpty { Section { Text(note) } }
                    Section {
                        if items.isEmpty { Text("Nothing to plan.").foregroundStyle(.secondary) }
                        ForEach($items) { $item in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(item.task.title)
                                    Spacer()
                                    Stepper("\(TimeInterval(item.minutes * 60).hoursMinutes)",
                                            value: $item.minutes, in: 5...600, step: 15)
                                        .fixedSize()
                                }
                                Text([item.task.project?.name, item.reason].compactMap { $0 }.joined(separator: " · "))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .onMove { items.move(fromOffsets: $0, toOffset: $1) }
                        .onDelete { items.remove(atOffsets: $0) }
                    } header: {
                        Text("Total \(TimeInterval(items.reduce(0) { $0 + $1.minutes } * 60).hoursMinutes)")
                    } footer: {
                        Text("Drag to reorder, swipe to remove. Nothing is saved until you accept.")
                    }
                }
            }
            .navigationTitle("Plan My Day")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Discard") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Accept") {
                        DayPlanner.accept(items, allTasks: tasks)
                        dismiss()
                    }
                    .disabled(loading || error != nil || items.isEmpty)
                }
                #if !os(macOS)
                ToolbarItem { EditButton() }
                #endif
            }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 420)
        #endif
        .task { plan() }
    }

    private func plan() {
        let now = Date.now
        let today = DayMath.day(now)
        let yesterday = DateInterval(start: Calendar.current.date(byAdding: .day, value: -1, to: today.start)!, end: today.end)
        let snapshot = AISnapshot(projects: projects, entries: entries, tasks: tasks, range: yesterday, now: now)
        loading = true
        error = nil
        Task {
            do {
                let events = await CalendarAccess.todayEvents(now: now)
                var prompt = "\(snapshot.text)\n\n\(DayPlanner.remainingLine(projects: projects, now: now))"
                if let meetings = DayPlanner.meetingsLine(events.map { ($0.title, $0.start, $0.end) }) {
                    prompt += "\n\n\(meetings)"
                }
                let res = try await ClaudeClient.send(ClaudeRequest(
                    system: DayPlanner.system,
                    messages: [["role": "user", "content": .string(prompt + "\n\nPlan my day.")]],
                    effort: "medium",
                    schema: DayPlanner.schema))
                guard let parsed = DayPlanner.items(from: res.text, openTasks: snapshot.openTasks) else {
                    throw ClaudeError.invalidResponse
                }
                items = parsed.items
                note = parsed.note
            } catch {
                self.error = error.localizedDescription
            }
            loading = false
        }
    }
}

/// Today's accepted plan, in order.
struct PlanSection: View {
    @Query(sort: \TaskItem.planOrder) private var tasks: [TaskItem]
    let now: Date

    var body: some View {
        let today = DayMath.logicalDate(now)
        let planned = tasks.filter { $0.plannedFor == today }
        if !planned.isEmpty {
            Section {
                ForEach(planned) { t in
                    HStack {
                        TaskRow(task: t)
                        if let m = t.plannedMinutes {
                            Text(TimeInterval(m * 60).hoursMinutes).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Plan")
                    Spacer()
                    Button("Clear") { planned.forEach { $0.plannedFor = nil; $0.plannedMinutes = nil } }
                        .font(.caption)
                }
            }
        }
    }
}
