//
//  QuickAddParser.swift
//  Do-Du
//
//  On-device sentence → task fields (Apple Foundation Models).
//

import Foundation
import FoundationModels

@Generable(description: "A to-do task extracted from one sentence")
struct TaskDraft {
    @Guide(description: "Short task title, without project, date or duration words")
    var title: String
    @Guide(description: "One of the listed project names if the sentence mentions it, otherwise empty")
    var project: String
    @Guide(description: "One of the listed category names if the sentence mentions it, otherwise empty")
    var category: String
    @Guide(description: "Days from today until due: 0 today, 1 tomorrow. -1 if no due date is mentioned")
    var dueInDays: Int
    @Guide(description: "Duration in minutes if mentioned (2h = 120), otherwise 0")
    var estimateMinutes: Int
}

/// What the task editor starts with.
struct TaskPrefill {
    var title: String
    var project: Project?
    var category: Category?
    var dueDate: Date?
    var estimateMinutes: Int?
}

enum QuickAddParser {
    static var isAvailable: Bool { SystemLanguageModel.default.isAvailable }

    static func parse(_ text: String, projects: [Project], categories: [Category],
                      now: Date = .now) async throws -> TaskPrefill {
        let session = LanguageModelSession(instructions: """
            Extract one to-do task from the user's sentence.
            Today is \(now.formatted(.dateTime.weekday(.wide).day().month(.wide).year())).
            Projects: \(projects.map(\.name).joined(separator: ", ")).
            Categories: \(categories.map(\.name).joined(separator: ", ")).
            Only use a project or category name from these lists.
            """)
        let draft = try await session.respond(to: text, generating: TaskDraft.self).content
        return prefill(from: draft, projects: projects, categories: categories, now: now)
    }

    /// Maps model output onto real objects. Unknown names stay nil (never auto-created).
    static func prefill(from d: TaskDraft, projects: [Project], categories: [Category],
                        now: Date, calendar: Calendar = .current) -> TaskPrefill {
        func match<T>(_ name: String, in items: [T], _ key: (T) -> String) -> T? {
            let n = name.trimmingCharacters(in: .whitespaces)
            return n.isEmpty ? nil : items.first { key($0).localizedCaseInsensitiveCompare(n) == .orderedSame }
        }
        return TaskPrefill(
            title: d.title.trimmingCharacters(in: .whitespacesAndNewlines),
            project: match(d.project, in: projects, \.name),
            category: match(d.category, in: categories, \.name),
            dueDate: d.dueInDays >= 0
                ? calendar.date(byAdding: .day, value: d.dueInDays, to: calendar.startOfDay(for: now)) : nil,
            estimateMinutes: d.estimateMinutes > 0 ? d.estimateMinutes : nil)
    }
}
