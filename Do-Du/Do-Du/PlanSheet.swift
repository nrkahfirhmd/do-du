//
//  PlanSheet.swift
//  Do-Du
//

import SwiftUI
import SwiftData

struct PlanSheet: View {
    @Environment(\.dismiss) private var dismiss
    #if os(macOS)
    @Environment(\.openSettings) private var openSettings
    @AppStorage("macSettingsTab") private var settingsTab = "general"
    #endif
    @Query(sort: \Project.createdAt) private var projects: [Project]
    @Query private var entries: [TimeEntry]
    @Query private var tasks: [TaskItem]
    @State private var items: [PlanItem] = []
    @State private var note = ""
    @State private var loading = true
    @State private var error: String?
    @State private var meetingMinutes = 0
    private let hasKey = ClaudeKey.current != nil

    private var canAccept: Bool { hasKey && !loading && error == nil && !items.isEmpty }

    var body: some View {
        #if os(macOS)
        MacSheet(title: "Plan My Day",
                 subtitle: "Suggested by Claude from your open tasks, today’s targets and your calendar.",
                 cancel: "Discard", primary: "Accept Plan", primaryHint: "⌘↩",
                 primaryKey: KeyboardShortcut(.return, modifiers: .command),
                 canSubmit: canAccept, submit: accept, width: 620) {
            VStack(spacing: 14) {
                if hasKey {
                    stats
                    VStack(spacing: 0) { states }
                        .background(DD.surface, in: .dd(18))
                } else {
                    noKey
                }
            }
            .padding(.horizontal, 20).padding(.top, 12)
        } footer: {
            Text("Nothing is saved until you accept.").font(.system(size: 12)).foregroundStyle(DD.ink3)
        }
        .sensoryFeedback(.error, trigger: error) { _, new in new != nil }
        .task { if hasKey { plan() } }
        #else
        NavigationStack {
            List {
                Group {
                    if !hasKey {
                        noKey
                    } else {
                        Section { stats }.listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                        Section {
                            states
                        } footer: {
                            Text("Drag to reorder, swipe to remove. Nothing is saved until you accept.")
                        }
                    }
                }
                .ddRows()
            }
            .ddForm()
            .navigationTitle("Plan My Day")
            .sensoryFeedback(.error, trigger: error) { _, new in new != nil }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Discard") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Accept", action: accept).ddPrimary().disabled(!canAccept)
                }
                ToolbarItem { EditButton() }
            }
        }
        .task { if hasKey { plan() } }
        #endif
    }

    private func accept() {
        DayPlanner.accept(items, allTasks: tasks)
        dismiss()
    }

    // MARK: Pieces

    /// Planned · To enough · Meetings. Planned gets the mint tag once it covers what's left.
    private var stats: some View {
        let now = Date.now
        let planned = items.reduce(0) { $0 + $1.minutes }
        let left: Int = switch Stats.verdict(for: projects, on: now, now: now) {
        case .notYet(let r): Int(r / 60)
        default: 0
        }
        let cells: [(String, String, Bool)] = [
            ("Planned", compactHours(planned), left > 0 && planned >= left),
            ("To enough", left > 0 ? compactHours(left) : "Done", false),
            ("Meetings", compactHours(meetingMinutes), false),
        ]
        return HStack(spacing: 0) {
            ForEach(cells.indices, id: \.self) { i in
                HStack(spacing: 0) {
                    if i > 0 { Rectangle().fill(DD.separator).frame(width: 1).padding(.trailing, 18) }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(cells[i].1).font(.rounded(24)).monospacedDigit().foregroundStyle(DD.forest)
                            .padding(.horizontal, cells[i].2 ? 4 : 0)
                            .background(cells[i].2 ? DD.mint : .clear, in: .rect(cornerRadius: 7))
                        Text(cells[i].0.uppercased()).font(.rounded(11, .bold)).tracking(1.1).foregroundStyle(DD.ink3)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(EdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18))
        .background(DD.surface, in: .dd(18))
        .animation(DD.fillChange, value: planned)
    }

    @ViewBuilder private var states: some View {
        if loading {
            ProgressView("Planning your day…").frame(maxWidth: .infinity).padding(20)
        } else if let error {
            VStack(alignment: .leading, spacing: 8) {
                Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(DD.danger)
                Button("Try Again", action: plan)
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(16)
        } else {
            if !note.isEmpty {
                Text(note).font(.subheadline).foregroundStyle(DD.ink3)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(14)
            }
            if items.isEmpty { Text("Nothing to plan.").foregroundStyle(DD.ink3).padding(14) }
            ForEach(Array($items.enumerated()), id: \.element.id) { index, $item in
                #if os(macOS)
                if index > 0 || !note.isEmpty { Divider().padding(.leading, 14) }
                #endif
                PlanRow(number: index + 1, item: $item)
            }
            .onMove { items.move(fromOffsets: $0, toOffset: $1) }
            .onDelete { items.remove(atOffsets: $0) }
        }
    }

    private var noKey: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Plan My Day needs a Claude API key.").font(.rounded(17, .bold)).foregroundStyle(DD.ink)
            Text("Add one in Settings → Assistant. The timer, tasks and Quick Add keep working without it.")
                .font(.system(size: 13)).foregroundStyle(DD.ink3)
            #if os(macOS)
            Button("Open Settings") {
                settingsTab = "assistant"
                dismiss()
                openSettings()
            }
            .buttonStyle(CapsuleButton(fill: DD.forestFill, ink: .white))
            #endif
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(DD.surface, in: .dd(18))
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
                meetingMinutes = Int(events.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) } / 60)
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

/// Numbered suggestion: title, project swatch and reason (Danger when due), ±15m stepper.
private struct PlanRow: View {
    let number: Int
    @Binding var item: PlanItem

    var body: some View {
        let due = item.task.dueDate.map { $0 <= DayMath.logicalDate(.now) } ?? false
        HStack(spacing: 12) {
            Text("\(number)").font(.rounded(12, .bold)).foregroundStyle(DD.forest)
                .frame(width: 24, height: 24).background(DD.fill, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(item.task.title).font(.system(size: 14, weight: .medium)).foregroundStyle(DD.ink)
                HStack(spacing: 6) {
                    if let project = item.task.project {
                        RoundedRectangle(cornerRadius: 3, style: .continuous).fill(project.color).frame(width: 8, height: 8)
                        Text(project.name)
                    }
                    if !item.reason.isEmpty { Text(item.reason).foregroundStyle(due ? DD.danger : DD.ink3) }
                }
                .font(.system(size: 12)).foregroundStyle(DD.ink3).lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(compactHours(item.minutes)).font(.rounded(13, .bold)).monospacedDigit()
            Stepper("Minutes", value: $item.minutes, in: 15...240, step: 15).labelsHidden()
        }
        .padding(.vertical, 8)
        #if os(macOS)
        .padding(.horizontal, 14)
        #endif
        .frame(minHeight: 58)
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
