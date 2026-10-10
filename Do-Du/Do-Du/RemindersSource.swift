//
//  RemindersSource.swift
//  Do-Du
//
//  One-way import from Apple Reminders. Each reminder list name maps to a
//  Do-Du project (case-insensitive); nothing is ever written back.
//

import EventKit
import Foundation

enum RemindersError: LocalizedError, Equatable {
    case noAccess

    var errorDescription: String? {
        "Allow Reminders access in Settings to import."
    }
}

enum RemindersSource: TaskSource {
    static let id = "reminders"
    static let displayName = "Reminders"

    static func isConfigured() -> Bool {
        EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
    }

    static func requestAccess() async -> Bool {
        (try? await EKEventStore().requestFullAccessToReminders()) ?? false
    }

    static func fetchDrafts() async throws -> [ExternalDraft] {
        guard isConfigured() else { throw RemindersError.noAccess }
        let store = EKEventStore()
        let predicate = store.predicateForReminders(in: nil)
        let calendar = Calendar.current
        // Map inside the callback so only plain values cross threads.
        return await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                let drafts = (reminders ?? []).compactMap { r in
                    draft(id: r.calendarItemExternalIdentifier ?? r.calendarItemIdentifier,
                          title: r.title ?? "", isDone: r.isCompleted,
                          due: r.dueDateComponents, list: r.calendar?.title, calendar: calendar)
                }
                continuation.resume(returning: drafts)
            }
        }
    }

    /// Pure mapping. Nil for untitled reminders (nothing importable).
    /// The external identifier is preferred so the same reminder links once across devices.
    nonisolated static func draft(id: String, title: String, isDone: Bool, due: DateComponents?,
                                  list: String?, calendar: Calendar) -> ExternalDraft? {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !id.isEmpty else { return nil }
        let dueDate = due.flatMap { c -> Date? in
            guard let y = c.year, let m = c.month, let d = c.day else { return nil }
            return calendar.date(from: DateComponents(year: y, month: m, day: d))
        }
        return ExternalDraft(source: "reminders", externalID: id, title: t, isDone: isDone,
                             dueDate: dueDate, projectName: list)
    }
}
