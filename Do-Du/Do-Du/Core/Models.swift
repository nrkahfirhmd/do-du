import Foundation
import SwiftData
import SwiftUI

@Model
final class Project {
    var name: String = ""
    var colorName: String = Palette.names[0]
    var dailyTargetMinutes: Int = 0
    /// Bit `n` set = active on Calendar weekday `n + 1` (1 = Sunday … 7 = Saturday).
    var activeWeekdaysMask: Int = Weekdays.monToFri
    var isArchived: Bool = false
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \TaskItem.project)
    var tasks: [TaskItem]? = []

    @Relationship(deleteRule: .cascade, inverse: \TimeEntry.project)
    var looseEntries: [TimeEntry]? = []

    init(
        name: String, colorName: String = Palette.names[0], dailyTargetMinutes: Int = 0,
        activeWeekdaysMask: Int = Weekdays.monToFri
    ) {
        self.name = name
        self.colorName = colorName
        self.dailyTargetMinutes = dailyTargetMinutes
        self.activeWeekdaysMask = activeWeekdaysMask
    }

    var color: Color { Palette.color(colorName) }
    var dailyTarget: TimeInterval { TimeInterval(dailyTargetMinutes * 60) }
}

@Model
final class Category {
    var name: String = ""
    var colorName: String = Palette.names[0]

    @Relationship(deleteRule: .nullify, inverse: \TaskItem.category)
    var tasks: [TaskItem]? = []

    init(name: String, colorName: String = Palette.names[0]) {
        self.name = name
        self.colorName = colorName
    }

    var color: Color { Palette.color(colorName) }
}

/// Named `TaskItem` to avoid clashing with Swift concurrency's `Task`.
@Model
final class TaskItem {
    var title: String = ""
    var notes: String = ""
    var dueDate: Date?
    var estimateMinutes: Int?
    var isDone: Bool = false
    var completedAt: Date?
    var createdAt: Date = Date.now
    var externalSource: String?
    var externalID: String?
    var plannedFor: Date?
    var planOrder: Int = 0
    var plannedMinutes: Int?

    var project: Project?
    var category: Category?

    @Relationship(deleteRule: .cascade, inverse: \TimeEntry.task)
    var entries: [TimeEntry]? = []

    init(title: String, project: Project?, category: Category? = nil) {
        self.title = title
        self.project = project
        self.category = category
    }

    func setDone(_ done: Bool) {
        isDone = done
        completedAt = done ? .now : nil
    }
}

@Model
final class TimeEntry {
    var start: Date = Date.now
    /// `nil` while the timer is running.
    var end: Date?
    var task: TaskItem?
    /// Only set for task-less entries; task entries get their project from the task.
    var project: Project?

    init(task: TaskItem?, project: Project? = nil, start: Date = .now, end: Date? = nil) {
        self.task = task
        self.project = task == nil ? project : nil
        self.start = start
        self.end = end
    }

    var isRunning: Bool { end == nil }
    var effectiveProject: Project? { task?.project ?? project }
    var title: String { task?.title ?? "Quick session" }
    func duration(now: Date = .now) -> TimeInterval { (end ?? now).timeIntervalSince(start) }
}

/// Older colour names still resolve, so no data migration is needed.
enum Palette {
    static let names = ["forest", "sage", "moss", "seafoam", "pine", "slate"]

    static func canonical(_ name: String) -> String {
        if names.contains(name) { return name }
        switch name {
        case "green": return "sage"
        case "teal": return "moss"
        case "yellow", "pink": return "seafoam"
        case "orange", "red": return "pine"
        case "purple", "gray": return "slate"
        default: return "forest"  // "blue" and anything unknown
        }
    }

    static func color(_ name: String) -> Color {
        switch canonical(name) {
        case "sage": Color.dynamic(light: Color(hex: 0x428475), dark: Color(hex: 0x6FB3A0))
        case "moss": Color(hex: 0x5E9C8C)
        case "seafoam": Color(hex: 0x9CC4B6)
        case "pine": Color.dynamic(light: Color(hex: 0x2F6B5D), dark: Color(hex: 0x4E9282))
        case "slate": Color(hex: 0x8B93A7)
        default: Color.dynamic(light: Color(hex: 0x1A312C), dark: Color(hex: 0xD7E8E1))
        }
    }
}

enum Weekdays {
    static let all = 0b111_1111
    static let monToFri = 0b011_1110
}

let allModels: [any PersistentModel.Type] = [Project.self, Category.self, TaskItem.self, TimeEntry.self]
