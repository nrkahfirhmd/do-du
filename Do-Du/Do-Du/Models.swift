//
//  Models.swift
//  Do-Du
//
//  CloudKit-compatible: every property has a default or is optional,
//  every relationship is optional with an inverse, no unique constraints.
//

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

    init(name: String, colorName: String = Palette.names[0], dailyTargetMinutes: Int = 0,
         activeWeekdaysMask: Int = Weekdays.monToFri) {
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
    /// Phase 3 integrations (Notion, Reminders, …). Nil for tasks created in Do-Du.
    var externalSource: String?
    var externalID: String?

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

    init(task: TaskItem?, start: Date = .now, end: Date? = nil) {
        self.task = task
        self.start = start
        self.end = end
    }

    var isRunning: Bool { end == nil }
    func duration(now: Date = .now) -> TimeInterval { (end ?? now).timeIntervalSince(start) }
}

enum Palette {
    static let names = ["blue", "green", "orange", "red", "purple", "pink", "teal", "yellow", "gray"]

    static func color(_ name: String) -> Color {
        switch name {
        case "green": .green
        case "orange": .orange
        case "red": .red
        case "purple": .purple
        case "pink": .pink
        case "teal": .teal
        case "yellow": .yellow
        case "gray": .gray
        default: .blue
        }
    }
}

enum Weekdays {
    static let all = 0b111_1111
    static let monToFri = 0b011_1110

    /// Calendar weekday symbols in Calendar order (index 0 = Sunday).
    static var shortSymbols: [String] { Calendar.current.veryShortWeekdaySymbols }
}

let allModels: [any PersistentModel.Type] = [Project.self, Category.self, TaskItem.self, TimeEntry.self]
