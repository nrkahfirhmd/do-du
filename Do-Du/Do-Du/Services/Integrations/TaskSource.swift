//
//  TaskSource.swift
//  Do-Du
//
//  Phase 3 boundary: external task lists plug in here so core models
//  stay untouched. Sources only ever produce drafts; the user confirms
//  before anything is written.
//

import Foundation
import SwiftData

/// One task row fetched from an external source. `projectName` is the
/// source's free-text project; the UI resolves it onto a local Project.
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

    /// Splits fetched drafts into rows already linked to a task (refreshed on import)
    /// and new rows worth offering. Finished rows are never offered as new tasks.
    static func split(_ drafts: [ExternalDraft], tasks: [TaskItem]) -> (new: [ExternalDraft], linked: [ExternalDraft]) {
        let linkedIDs = Set(tasks.filter { $0.externalSource == id }.compactMap(\.externalID))
        return (drafts.filter { !linkedIDs.contains($0.externalID) && !$0.isDone },
                drafts.filter { linkedIDs.contains($0.externalID) })
    }

    /// Inserts new drafts; refreshes title/done/due on already-linked tasks.
    /// Drafts without a resolvable project are skipped and reported.
    static func apply(_ drafts: [ExternalDraft], projects: [Project], in context: ModelContext) -> (inserted: Int, updated: Int, skipped: Int) {
        let linked = ((try? context.fetch(FetchDescriptor<TaskItem>())) ?? [])
            .filter { $0.externalSource == id }
        var inserted = 0, updated = 0, skipped = 0
        for d in drafts {
            if let t = linked.first(where: { $0.externalID == d.externalID }) {
                var changed = false
                if t.title != d.title { t.title = d.title; changed = true }
                if t.isDone != d.isDone { t.setDone(d.isDone); changed = true }
                if t.dueDate != d.dueDate { t.dueDate = d.dueDate; changed = true }
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
