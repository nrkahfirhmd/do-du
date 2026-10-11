import EventKit
import Foundation

struct DayEvent: Sendable, Equatable {
    var title: String
    var start: Date
    var end: Date
}

enum CalendarAccess {
    static let calendarKey = "ekCalendarID"
    /// Kept alive so `.EKEventStoreChanged` fires when the calendar changes.
    @MainActor static let store = EKEventStore()

    static var chosenID: String {
        UserDefaults.standard.string(forKey: calendarKey) ?? ""
    }

    @MainActor static func authorization() -> EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    @MainActor static func requestAccess() async -> Bool {
        (try? await EKEventStore().requestFullAccessToEvents()) ?? false
    }

    @MainActor static func calendars() async -> [(id: String, title: String)] {
        guard authorization() == .fullAccess else { return [] }
        return EKEventStore().calendars(for: .event)
            .map { ($0.calendarIdentifier, "\($0.title) (\($0.source.title))") }
            .sorted { $0.title < $1.title }
    }

    /// Empty when unconfigured or unauthorized — Today simply shows no schedule.
    @MainActor static func todayEvents(now: Date = .now) async -> [DayEvent] {
        guard !chosenID.isEmpty, authorization() == .fullAccess else { return [] }
        guard let calendar = store.calendars(for: .event).first(where: { $0.calendarIdentifier == chosenID })
        else { return [] }
        let day = DayMath.day(now)
        return store.events(matching: store.predicateForEvents(withStart: day.start, end: day.end, calendars: [calendar]))
            .map { DayEvent(title: $0.title, start: $0.startDate, end: $0.endDate) }
            .sorted { $0.start < $1.start }
    }
}
