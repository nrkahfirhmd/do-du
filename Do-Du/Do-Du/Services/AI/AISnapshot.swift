//
//  AISnapshot.swift
//  Do-Du
//
//  Compact, deterministic text view of the user's data for Claude. All numbers
//  are computed here; the model only reads them.
//

import Foundation

struct AISnapshot {
    let text: String
    /// Open tasks in the order listed in `text` (`[0]`, `[1]`, …) so model picks can be mapped back.
    let openTasks: [TaskItem]

    init(projects: [Project], entries: [TimeEntry], tasks: [TaskItem],
         range: DateInterval, now: Date = .now, calendar: Calendar = .current) {
        let day = DateFormatter()
        day.calendar = calendar
        day.timeZone = calendar.timeZone
        day.locale = Locale(identifier: "en_US_POSIX")
        day.dateFormat = "yyyy-MM-dd EEE"
        let mins = { (t: TimeInterval) in "\(Int(t / 60))m" }
        let projects = projects.sorted { ($0.createdAt, $0.name) < ($1.createdAt, $1.name) }
        let clipped = DateInterval(start: range.start, end: min(range.end, max(now, range.start)))

        var lines = ["Now: \(day.string(from: now)) \(now.formatted(.dateTime.hour().minute()))",
                     "Range: \(day.string(from: range.start)) to \(day.string(from: range.end.addingTimeInterval(-1)))",
                     "", "Projects (daily target · active days):"]
        for p in projects where !p.isArchived {
            let days = (0..<7).filter { p.activeWeekdaysMask & (1 << $0) != 0 }
                .map { calendar.shortWeekdaySymbols[$0] }.joined(separator: " ")
            lines.append("- \(p.name): \(mins(p.dailyTarget))/day · \(days.isEmpty ? "none" : days)")
        }

        lines += ["", "Tracked in range:"]
        for p in projects {
            let t = p.tracked(in: clipped, now: now)
            if t > 0 { lines.append("- \(p.name): \(mins(t))") }
        }
        let loose = entries.filter { $0.effectiveProject == nil }.tracked(in: clipped, now: now)
        if loose > 0 { lines.append("- No project (not counted toward targets): \(mins(loose))") }

        lines += ["", "Days (verdict | tracked/target per active project):"]
        for d in DayMath.logicalDates(in: clipped, calendar: calendar) {
            let interval = DayMath.dayStarting(d, calendar: calendar)
            let verdict = Stats.verdict(for: projects, on: interval.start, now: now, calendar: calendar)
            let parts = projects.filter { $0.isActive(on: interval.start, calendar: calendar) }
                .map { "\($0.name) \(Int($0.tracked(in: interval, now: now) / 60))/\($0.dailyTargetMinutes)" }
            let v: String = switch verdict {
            case .enough: "enough"
            case .restDay: "rest day"
            case .notYet(let r): "not enough (\(mins(r)) short)"
            }
            lines.append("- \(day.string(from: d)): \(v)\(parts.isEmpty ? "" : " | " + parts.joined(separator: ", "))")
        }

        let open = tasks.filter { !$0.isDone && $0.project?.isArchived == false }
            .sorted { ($0.dueDate ?? .distantFuture, $0.title) < ($1.dueDate ?? .distantFuture, $1.title) }
        lines += ["", "Open tasks:"]
        if open.isEmpty { lines.append("- none") }
        for (i, t) in open.enumerated() {
            var parts = ["[\(i)] \(t.title)", t.project?.name ?? "?"]
            if let c = t.category { parts.append(c.name) }
            if let due = t.dueDate { parts.append("due \(day.string(from: due))") }
            if let est = t.estimateMinutes { parts.append("est \(est)m") }
            lines.append("- " + parts.joined(separator: " · "))
        }

        let done = tasks.filter { t in t.completedAt.map { clipped.contains($0) } ?? false }
            .sorted { ($0.completedAt!, $0.title) < ($1.completedAt!, $1.title) }
        lines += ["", "Completed in range:"]
        if done.isEmpty { lines.append("- none") }
        for t in done { lines.append("- \(t.title) · \(t.project?.name ?? "?") · \(day.string(from: t.completedAt!))") }

        text = lines.joined(separator: "\n")
        openTasks = open
    }
}
