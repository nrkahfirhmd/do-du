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
                ? calendar.date(byAdding: .day, value: d.dueInDays, to: DayMath.logicalDate(now, calendar: calendar)) : nil,
            estimateMinutes: d.estimateMinutes > 0 ? d.estimateMinutes : nil)
    }
}

/// Instant offline read of Quick Add text: dates, `~estimate`, `#category` and project names.
struct QuickAddSyntax: Equatable {
    var title: String
    var projectName: String?
    var categoryName: String?
    var dueInDays: Int?
    var estimateMinutes: Int?

    static func read(_ text: String, projects: [String], categories: [String], weekday: Int) -> QuickAddSyntax {
        var rest = text
        func take(_ pattern: String) -> [String]? {
            guard let re = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let m = re.firstMatch(in: rest, range: NSRange(rest.startIndex..., in: rest)) else { return nil }
            let groups = (0..<m.numberOfRanges).map { i in
                Range(m.range(at: i), in: rest).map { String(rest[$0]) } ?? ""
            }
            rest.replaceSubrange(Range(m.range, in: rest)!, with: " ")
            return groups
        }

        var due: Int?
        if take(#"\btoday\b"#) != nil { due = 0 }
        else if take(#"\btomorrow\b"#) != nil { due = 1 }
        else if let g = take(#"\b(?:on\s+)?(mon|tue|wed|thu|fri|sat|sun)[a-z]*\b"#) {
            let names = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
            if let target = names.firstIndex(of: g[1].lowercased()) { due = (target + 1 - weekday + 7) % 7 }
        }

        var estimate: Int?
        if let g = take(#"~\s*(\d+(?:\.\d+)?)\s*(h|m)?\s*(?:(\d+)\s*m?)?"#) {
            let n = Double(g[1]) ?? 0
            let minutes = g[2].lowercased() == "h" ? n * 60 + (Double(g[3]) ?? 0) : n
            if minutes > 0 { estimate = Int(minutes.rounded()) }
        }

        var category: String?
        if let g = take(#"#([\w-]+)"#) {
            let tag = g[1].lowercased().replacingOccurrences(of: "-", with: "")
            func key(_ s: String) -> String { s.lowercased().replacingOccurrences(of: " ", with: "") }
            category = categories.first { key($0) == tag } ?? categories.first { key($0).hasPrefix(tag) }
        }

        // Longest name first so "Client X" beats "Client". The name stays in the title.
        let lower = rest.lowercased()
        let project = projects.sorted { $0.count > $1.count }.first { name in
            guard let r = lower.range(of: name.lowercased()) else { return false }
            let before = r.lowerBound == lower.startIndex ? " " : lower[lower.index(before: r.lowerBound)]
            let after = r.upperBound == lower.endIndex ? " " : lower[r.upperBound]
            return !before.isLetter && !after.isLetter
        }

        let title = rest.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return QuickAddSyntax(title: title, projectName: project, categoryName: category,
                              dueInDays: due, estimateMinutes: estimate)
    }
}
