//
//  TaskSource.swift
//  Do-Du
//
//  Phase 3 boundary: external task lists plug in here so core models
//  stay untouched. Sources only ever produce drafts; the user confirms
//  before anything is written.
//

import Foundation

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
