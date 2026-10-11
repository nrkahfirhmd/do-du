import Foundation

extension Collection where Element == TimeEntry {
    func tracked(in range: DateInterval, now: Date = .now) -> TimeInterval {
        reduce(0) { $0 + DayMath.overlap(start: $1.start, end: $1.end ?? now, with: range) }
    }
}

extension Project {
    var allEntries: [TimeEntry] { (tasks ?? []).flatMap { $0.entries ?? [] } + (looseEntries ?? []) }

    func tracked(in range: DateInterval, now: Date = .now) -> TimeInterval {
        allEntries.tracked(in: range, now: now)
    }

    func isActive(on date: Date, calendar: Calendar = .current) -> Bool {
        !isArchived && DayMath.isActive(mask: activeWeekdaysMask, on: date, calendar: calendar)
    }
}

extension Category {
    func tracked(in range: DateInterval, now: Date = .now) -> TimeInterval {
        (tasks ?? []).flatMap { $0.entries ?? [] }.tracked(in: range, now: now)
    }
}

enum Stats {
    static func verdict(for projects: [Project], on date: Date, now: Date = .now,
                        calendar: Calendar = .current) -> Verdict {
        let day = DayMath.day(date, calendar: calendar)
        return DayMath.verdict(projects
            .filter { $0.isActive(on: date, calendar: calendar) }
            .map { ($0.tracked(in: day, now: now), $0.dailyTarget) })
    }
}
