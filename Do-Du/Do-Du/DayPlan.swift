//
//  DayPlan.swift
//  Do-Du
//
//  Plan my day: Claude picks open tasks (by snapshot index) and minutes.
//  Nothing is written until the user accepts.
//

import Foundation

struct PlanItem: Identifiable, Equatable {
    let task: TaskItem
    var minutes: Int
    var reason: String
    var id: ObjectIdentifier { ObjectIdentifier(task) }
}

enum DayPlanner {
    static let schema: JSON = [
        "type": "object", "additionalProperties": false,
        "required": ["items", "note"],
        "properties": [
            "items": [
                "type": "array",
                "items": [
                    "type": "object", "additionalProperties": false,
                    "required": ["task", "minutes", "reason"],
                    "properties": [
                        "task": ["type": "integer", "description": "Index of an open task, e.g. 3 for [3]"],
                        "minutes": ["type": "integer"],
                        "reason": ["type": "string"],
                    ],
                ],
            ],
            "note": ["type": "string"],
        ],
    ]

    static let system = """
        You plan the user's work day in Do-Du, a personal to-do list and work timer whose goal is \
        letting the user know when they've done enough.

        From the open tasks (refer to them by their [index]), choose an ordered list for today and minutes \
        for each so every active project's remaining target is met where possible. Prefer overdue and \
        due-today tasks, then tasks with estimates that fit. Don't plan far beyond the remaining targets. \
        On a rest day, plan little or nothing. If a project needs time but has no suitable task, say in \
        the note that a quick timer can cover it.

        Each reason is at most 12 words. The note is at most two sentences.
        """

    /// Remaining minutes per active project today, for the prompt.
    static func remainingLine(projects: [Project], now: Date) -> String {
        let day = DayMath.day(now)
        let parts = projects.filter { $0.isActive(on: now) }.map {
            "\($0.name) \(max(0, Int(($0.dailyTarget - $0.tracked(in: day, now: now)) / 60)))m"
        }
        return parts.isEmpty ? "Remaining today: rest day (no active projects)." : "Remaining today: " + parts.joined(separator: ", ")
    }

    /// Maps the model's JSON onto real tasks. Unknown or repeated indexes are dropped; minutes clamped.
    static func items(from text: String, openTasks: [TaskItem]) -> (items: [PlanItem], note: String)? {
        guard let json = try? JSONDecoder().decode(JSON.self, from: Data(text.utf8)),
              let raw = json["items"]?.array else { return nil }
        var seen = Set<Int>()
        let items = raw.compactMap { r -> PlanItem? in
            guard let i = r["task"]?.int, openTasks.indices.contains(i), seen.insert(i).inserted else { return nil }
            return PlanItem(task: openTasks[i], minutes: min(max(r["minutes"]?.int ?? 30, 5), 600),
                            reason: r["reason"]?.string ?? "")
        }
        return (items, json["note"]?.string ?? "")
    }

    /// Replaces today's plan with `items` in order.
    static func accept(_ items: [PlanItem], allTasks: [TaskItem], now: Date = .now) {
        let today = DayMath.logicalDate(now)
        for t in allTasks where t.plannedFor == today { t.plannedFor = nil; t.plannedMinutes = nil }
        for (i, item) in items.enumerated() {
            item.task.plannedFor = today
            item.task.planOrder = i
            item.task.plannedMinutes = item.minutes
        }
    }
}
