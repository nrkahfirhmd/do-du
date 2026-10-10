//
//  ChatTools.swift
//  Do-Du
//
//  Read-only tools Claude can call from Chat. Results are computed locally.
//

import Foundation

struct ChatTools {
    let projects: [Project]
    let entries: [TimeEntry]
    let tasks: [TaskItem]
    var now: Date = .now
    var calendar: Calendar = .current

    static let definitions: [JSON] = [
        [
            "name": "time_summary",
            "description": "Tracked minutes between two dates (inclusive), grouped by project, category or day. Use for any question about how much time was spent.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "start": ["type": "string", "description": "First day, YYYY-MM-DD"],
                    "end": ["type": "string", "description": "Last day, YYYY-MM-DD (inclusive)"],
                    "group_by": ["type": "string", "enum": ["project", "category", "day"]],
                ],
                "required": ["start", "end", "group_by"],
            ],
        ],
        [
            "name": "list_tasks",
            "description": "Lists tasks with project, category, due date, estimate and completion date. Max 50 rows.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "status": ["type": "string", "enum": ["open", "done", "all"]],
                    "project": ["type": "string", "description": "Optional project name filter"],
                    "due_before": ["type": "string", "description": "Optional YYYY-MM-DD; only tasks due on or before it"],
                ],
                "required": ["status"],
            ],
        ],
        [
            "name": "day_verdicts",
            "description": "Whether each day between two dates (inclusive) was enough, with tracked/target minutes per active project.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "start": ["type": "string", "description": "First day, YYYY-MM-DD"],
                    "end": ["type": "string", "description": "Last day, YYYY-MM-DD (inclusive)"],
                ],
                "required": ["start", "end"],
            ],
        ],
    ]

    func run(_ use: ToolUse) -> (result: String, isError: Bool) {
        do {
            switch use.name {
            case "time_summary": return (try timeSummary(use.input), false)
            case "list_tasks": return (try listTasks(use.input), false)
            case "day_verdicts": return (try dayVerdicts(use.input), false)
            default: return ("Unknown tool \(use.name)", true)
            }
        } catch {
            return (error.localizedDescription, true)
        }
    }

    struct BadInput: LocalizedError { let errorDescription: String? }

    private var dayFormat: DateFormatter {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    private func date(_ input: JSON, _ key: String) throws -> Date {
        guard let s = input[key]?.string, let d = dayFormat.date(from: s) else {
            throw BadInput(errorDescription: "\(key) must be a date like 2026-10-05")
        }
        return d
    }

    private func range(_ input: JSON) throws -> DateInterval {
        let start = try date(input, "start"), end = try date(input, "end")
        guard start <= end else { throw BadInput(errorDescription: "start must not be after end") }
        return DateInterval(start: DayMath.dayStarting(start, calendar: calendar).start,
                            end: DayMath.dayStarting(end, calendar: calendar).end)
    }

    private func timeSummary(_ input: JSON) throws -> String {
        let r = try range(input)
        let key: (TimeEntry) -> String
        switch input["group_by"]?.string {
        case "project": key = { $0.effectiveProject?.name ?? "No project" }
        case "category": key = { $0.task?.category?.name ?? "Uncategorized" }
        case "day":
            let f = dayFormat
            return DayMath.logicalDates(in: r, calendar: calendar).map { d in
                "\(f.string(from: d)): \(Int(entries.tracked(in: DayMath.dayStarting(d, calendar: calendar), now: now) / 60))m"
            }.joined(separator: "\n")
        default: throw BadInput(errorDescription: "group_by must be project, category or day")
        }
        let rows = Dictionary(grouping: entries, by: key)
            .map { ($0.key, Int($0.value.tracked(in: r, now: now) / 60)) }
            .filter { $0.1 > 0 }
            .sorted { ($1.1, $0.0) < ($0.1, $1.0) }
        let total = rows.reduce(0) { $0 + $1.1 }
        return (rows.map { "\($0.0): \($0.1)m" } + ["Total: \(total)m"]).joined(separator: "\n")
    }

    private func listTasks(_ input: JSON) throws -> String {
        let f = dayFormat
        let dueBefore = input["due_before"] == nil ? nil : try date(input, "due_before")
        let name = input["project"]?.string
        let rows = tasks.filter { t in
            switch input["status"]?.string {
            case "open": !t.isDone
            case "done": t.isDone
            default: true
            }
        }
        .filter { name == nil || $0.project?.name.localizedCaseInsensitiveCompare(name!) == .orderedSame }
        .filter { t in dueBefore.map { d in t.dueDate.map { $0 <= d } ?? false } ?? true }
        .sorted { ($0.dueDate ?? .distantFuture, $0.title) < ($1.dueDate ?? .distantFuture, $1.title) }
        if rows.isEmpty { return "No matching tasks." }
        return rows.prefix(50).map { t in
            var parts = [t.title, t.project?.name ?? "?"]
            if let c = t.category { parts.append(c.name) }
            if let d = t.dueDate { parts.append("due \(f.string(from: d))") }
            if let e = t.estimateMinutes { parts.append("est \(e)m") }
            if let c = t.completedAt { parts.append("done \(f.string(from: c))") }
            return parts.joined(separator: " · ")
        }.joined(separator: "\n")
    }

    private func dayVerdicts(_ input: JSON) throws -> String {
        let r = try range(input)
        let f = dayFormat
        return DayMath.logicalDates(in: r, calendar: calendar).compactMap { d in
            let day = DayMath.dayStarting(d, calendar: calendar)
            guard day.start <= now else { return nil }
            let v: String = switch Stats.verdict(for: projects, on: day.start, now: now, calendar: calendar) {
            case .enough: "enough"
            case .restDay: "rest day"
            case .notYet(let left): "not enough (\(Int(left / 60))m short)"
            }
            let parts = projects.filter { $0.isActive(on: day.start, calendar: calendar) }
                .map { "\($0.name) \(Int($0.tracked(in: day, now: now) / 60))/\($0.dailyTargetMinutes)" }
            return "\(f.string(from: d)): \(v)" + (parts.isEmpty ? "" : " | " + parts.joined(separator: ", "))
        }.joined(separator: "\n")
    }
}
