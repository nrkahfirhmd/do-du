import Foundation
import SwiftData

struct ExternalDraft: Identifiable {
    var source: String
    var externalID: String
    var title: String
    var isDone: Bool
    var dueDate: Date?
    var projectName: String?
    var id: String { source + ":" + externalID }
}

protocol TaskSource {
    static var id: String { get }
    static var displayName: String { get }
    static func isConfigured() -> Bool
    static func fetchDrafts() async throws -> [ExternalDraft]
}

/// Shared one-way import (the source wins): same rules for every source.
extension TaskSource {
    /// Case-insensitive match onto an existing project. Never auto-creates.
    static func resolveProject(_ name: String?, in projects: [Project]) -> Project? {
        guard let n = name?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty else { return nil }
        return projects.first { $0.name.localizedCaseInsensitiveCompare(n) == .orderedSame }
    }

    static func split(_ drafts: [ExternalDraft], tasks: [TaskItem]) -> (new: [ExternalDraft], linked: [ExternalDraft]) {
        let linkedIDs = Set(tasks.filter { $0.externalSource == id }.compactMap(\.externalID))
        return (
            drafts.filter { !linkedIDs.contains($0.externalID) && !$0.isDone },
            drafts.filter { linkedIDs.contains($0.externalID) }
        )
    }

    static func apply(_ drafts: [ExternalDraft], projects: [Project], in context: ModelContext) -> (
        inserted: Int, updated: Int, skipped: Int
    ) {
        let linked = ((try? context.fetch(FetchDescriptor<TaskItem>())) ?? [])
            .filter { $0.externalSource == id }
        var inserted = 0
        var updated = 0
        var skipped = 0
        for d in drafts {
            if let t = linked.first(where: { $0.externalID == d.externalID }) {
                var changed = false
                if t.title != d.title {
                    t.title = d.title
                    changed = true
                }
                if t.isDone != d.isDone {
                    t.setDone(d.isDone)
                    changed = true
                }
                if t.dueDate != d.dueDate {
                    t.dueDate = d.dueDate
                    changed = true
                }
                if changed { updated += 1 }
            } else if let p = resolveProject(d.projectName, in: projects) {
                let t = TaskItem(title: d.title, project: p)
                t.externalSource = id
                t.externalID = d.externalID
                t.dueDate = d.dueDate
                if d.isDone { t.setDone(true) }
                context.insert(t)
                inserted += 1
            } else {
                skipped += 1
            }
        }
        try? context.save()
        return (inserted, updated, skipped)
    }
}

/// Automatic import: same rules as the sheet, minus the per-item review.
extension TaskSource {
    /// New unfinished items whose project name matches, plus every linked item so its task refreshes.
    /// Unmatched items are left for the import sheet; projects are never created.
    static func autoDrafts(_ drafts: [ExternalDraft], tasks: [TaskItem], projects: [Project]) -> [ExternalDraft] {
        let s = split(drafts, tasks: tasks)
        return s.new.filter { resolveProject($0.projectName, in: projects) != nil } + s.linked
    }

    @discardableResult
    static func autoImport(in context: ModelContext) async throws -> Int {
        guard isConfigured() else { return 0 }
        let drafts = try await fetchDrafts()
        let tasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        let projects = (try? context.fetch(FetchDescriptor<Project>(predicate: #Predicate { !$0.isArchived }))) ?? []
        let r = apply(autoDrafts(drafts, tasks: tasks, projects: projects), projects: projects, in: context)
        return r.inserted
    }
}

enum ExternalLinks {
    /// Two devices can import the same item before CloudKit syncs; keep the oldest task and move time onto it.
    static func removeDuplicates(in context: ModelContext) {
        let linked =
            ((try? context.fetch(FetchDescriptor<TaskItem>(sortBy: [SortDescriptor(\.createdAt)])))
            ?? []).filter { $0.externalSource != nil && $0.externalID != nil }
        var keep: [String: TaskItem] = [:]
        var removed = false
        for t in linked {
            let key = t.externalSource! + ":" + t.externalID!
            guard let first = keep[key] else {
                keep[key] = t
                continue
            }
            for e in t.entries ?? [] { e.task = first }
            context.delete(t)
            removed = true
        }
        if removed { try? context.save() }
    }
}
