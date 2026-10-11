//
//  RecapView.swift
//  Do-Du
//
//  Computed numbers first, then Claude's short write-up of those numbers.
//

import SwiftUI
import SwiftData
import UserNotifications

struct RecapView: View {
    enum Span: String, CaseIterable, Identifiable {
        case today = "Today", week = "This Week"
        var id: Self { self }
    }

    @Query(sort: \Project.createdAt) private var projects: [Project]
    @Query private var entries: [TimeEntry]
    @Query private var tasks: [TaskItem]
    @State private var span = Span.today
    @State private var writeUps: [Span: String] = [:]
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        let now = Date.now
        let range = span == .today ? DayMath.day(now) : DayMath.period(.weekOfYear, for: now)
        let elapsed = DateInterval(start: range.start, end: min(range.end, now))
        let days = DayMath.logicalDates(in: elapsed).map { DayMath.dayStarting($0) }

        List {
            Picker("Span", selection: $span) {
                ForEach(Span.allCases) { Text($0.rawValue) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())

            Section("Numbers") {
                let tracked = entries.tracked(in: elapsed, now: now)
                LabeledContent("Tracked", value: tracked.hoursMinutes)
                let verdicts = days.map { Stats.verdict(for: projects, on: $0.start, now: now) }
                let workDays = verdicts.filter { $0 != .restDay }.count
                if span == .today {
                    LabeledContent("Verdict", value: verdictText(verdicts.first ?? .restDay))
                } else {
                    LabeledContent("Enough days", value: workDays == 0 ? "—" : "\(verdicts.filter { $0 == .enough }.count) of \(workDays)")
                }
                ForEach(projects.filter { !$0.isArchived }) { p in
                    let target = days.filter { p.isActive(on: $0.start) }.reduce(0) { a, _ in a + p.dailyTarget }
                    let t = p.tracked(in: elapsed, now: now)
                    if target > 0 || t > 0 {
                        LabeledContent { Text("\(t.hoursMinutes) / \(target.hoursMinutes)").monospacedDigit() }
                            label: {
                                HStack(spacing: 10) {
                                    RoundedRectangle(cornerRadius: 3, style: .continuous).fill(p.color).frame(width: 10, height: 10)
                                    Text(p.name)
                                }
                            }
                    }
                }
                let loose = entries.filter { $0.effectiveProject == nil }.tracked(in: elapsed, now: now)
                if loose > 0 { LabeledContent("No project", value: loose.hoursMinutes) }
                LabeledContent("Tasks done", value: "\(tasks.filter { $0.completedAt.map(elapsed.contains) ?? false }.count)")
            }

            .listRowBackground(DD.surface)
            .font(.body)
            .labeledContentStyle(DDValueStyle())

            Section("Recap") {
                if let text = writeUps[span] {
                    Text(text).textSelection(.enabled)
                }
                if let error { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(DD.danger) }
                if loading {
                    ProgressView("Writing…")
                } else {
                    Button(writeUps[span] == nil ? "Write Recap" : "Rewrite", systemImage: "sparkles") {
                        write(range: range, now: now)
                    }
                }
            }
            .listRowBackground(DD.surface)
        }
        .scrollContentBackground(.hidden)
        .background(DD.page)
        .tint(DD.sage)
        #if !os(macOS)
        .navigationTitle("Recap")   // Mac shows both side by side under "Assistant"
        #endif
        .sensoryFeedback(.error, trigger: error) { _, new in new != nil }
        .onChange(of: span) { error = nil }
    }

    private func verdictText(_ v: Verdict) -> String {
        switch v {
        case .enough: "Enough ✓"
        case .restDay: "Rest day"
        case .notYet(let r): "\(r.hoursMinutes) to go"
        }
    }

    private func write(range: DateInterval, now: Date) {
        let snapshot = AISnapshot(projects: projects, entries: entries, tasks: tasks, range: range, now: now)
        let which = span
        loading = true
        error = nil
        Task {
            do {
                let res = try await ClaudeClient.send(ClaudeRequest(
                    system: Self.system,
                    messages: [["role": "user", "content": .string(
                        "\(snapshot.text)\n\nWrite my \(which == .today ? "daily" : "weekly") recap.")]]))
                writeUps[which] = res.text.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                self.error = error.localizedDescription
            }
            loading = false
        }
    }

    static let system = """
        You write short recaps for Do-Du, a personal to-do list and work timer. Its purpose is to tell \
        the user honestly whether they did enough, so they can stop working without guilt.

        Use only the numbers in the data. Never invent, estimate or re-add totals. Say plainly whether \
        the day (or each day of the week) was enough. If there is "No project" time, mention it and that \
        it does not count toward targets until assigned. Add one concrete, useful observation.

        Write in second person, warm but not gushing, under 120 words, plain text with no headings or lists.
        """
}

/// Optional daily nudge to open the recap. Text is generic because a repeating
/// notification can't compute totals at fire time, and no network call happens in the background.
enum RecapReminder {
    static let enabledKey = "recapReminderOn"
    static let minutesKey = "recapReminderMinutes"   // minutes after midnight
    private static let id = "recap-reminder"

    static func apply(enabled: Bool, minutesAfterMidnight: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard enabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "How did today go?"
        content.body = "Open Do-Du to see whether you did enough."
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: minutesAfterMidnight / 60, minute: minutesAfterMidnight % 60), repeats: true)
        Task {
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
            try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }
}

/// Values in SF Rounded medium, Ink 3, tabular.
struct DDValueStyle: LabeledContentStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label.foregroundStyle(DD.ink)
            Spacer()
            configuration.content.font(.rounded(16, .medium)).monospacedDigit().foregroundStyle(DD.ink3)
        }
        .frame(minHeight: 32)
    }
}
