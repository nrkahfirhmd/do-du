//
//  DayMath.swift
//  Do-Du
//
//  Pure date/time math shared by Today, Stats and the timer. No SwiftData here,
//  so `checks/run.sh` can exercise it directly.
//

import Foundation

enum Verdict: Equatable {
    case notYet(remaining: TimeInterval)
    case enough
    case restDay
}

enum DayMath {
    static let startHourKey = "dayStartHour"
    /// Hour (0–6) when a day begins. Late-night work before it counts toward the previous day.
    static var startHour: Int { UserDefaults.standard.integer(forKey: startHourKey) }

    /// Calendar date (midnight) of the day `date` belongs to, honouring `startHour`.
    static func logicalDate(_ date: Date, calendar: Calendar = .current, startHour: Int = startHour) -> Date {
        calendar.startOfDay(for: calendar.date(byAdding: .hour, value: -startHour, to: date)!)
    }

    /// The day that begins on calendar date `logical` (at `startHour`).
    static func dayStarting(_ logical: Date, calendar: Calendar = .current, startHour: Int = startHour) -> DateInterval {
        let start = calendar.date(byAdding: .hour, value: startHour, to: calendar.startOfDay(for: logical))!
        return DateInterval(start: start, end: calendar.date(byAdding: .day, value: 1, to: start)!)
    }

    /// The day containing instant `date`.
    static func day(_ date: Date, calendar: Calendar = .current, startHour: Int = startHour) -> DateInterval {
        dayStarting(logicalDate(date, calendar: calendar, startHour: startHour), calendar: calendar, startHour: startHour)
    }

    /// Week / month containing `date`, shifted by `startHour`.
    static func period(_ component: Calendar.Component, for date: Date, calendar: Calendar = .current,
                       startHour: Int = startHour) -> DateInterval {
        let base = calendar.dateInterval(of: component, for: logicalDate(date, calendar: calendar, startHour: startHour))!
        return DateInterval(start: calendar.date(byAdding: .hour, value: startHour, to: base.start)!,
                            end: calendar.date(byAdding: .hour, value: startHour, to: base.end)!)
    }

    /// Calendar dates (midnights) of every day starting inside `range`.
    static func logicalDates(in range: DateInterval, calendar: Calendar = .current, startHour: Int = startHour) -> [Date] {
        var out: [Date] = []
        var d = logicalDate(range.start, calendar: calendar, startHour: startHour)
        while dayStarting(d, calendar: calendar, startHour: startHour).start < range.end {
            out.append(d)
            d = calendar.date(byAdding: .day, value: 1, to: d)!
        }
        return out
    }

    /// Seconds of `[start, end)` that fall inside `range`. Splits entries across midnight for free.
    static func overlap(start: Date, end: Date, with range: DateInterval) -> TimeInterval {
        max(0, min(end, range.end).timeIntervalSince(max(start, range.start)))
    }

    /// `mask` bit `n` = Calendar weekday `n + 1` (1 = Sunday).
    static func isActive(mask: Int, on date: Date, calendar: Calendar = .current) -> Bool {
        mask & (1 << (calendar.component(.weekday, from: logicalDate(date, calendar: calendar)) - 1)) != 0
    }

    /// One `(tracked, target)` pair per project active that day.
    static func verdict(_ progress: [(tracked: TimeInterval, target: TimeInterval)]) -> Verdict {
        if progress.isEmpty { return .restDay }
        let remaining = progress.reduce(0) { $0 + max(0, $1.target - $1.tracked) }
        return remaining <= 0 ? .enough : .notYet(remaining: remaining)
    }

    /// Index of the first span overlapping `[start, end)`. Touching edges don't count.
    static func firstConflict(start: Date, end: Date, in spans: [(start: Date, end: Date)]) -> Int? {
        spans.firstIndex { start < $0.end && $0.start < end }
    }

    /// When several timers run at once (e.g. after an offline sync), keep the latest start.
    static func runningToKeep(_ starts: [Date]) -> Int? {
        starts.indices.max { starts[$0] < starts[$1] }
    }
}

extension TimeInterval {
    /// "2h 05m", "45m", "0m".
    var hoursMinutes: String {
        let m = Int(self / 60)
        return m >= 60 ? String(format: "%dh %02dm", m / 60, m % 60) : "\(m)m"
    }

    /// "1:02:03" for a running timer.
    var clock: String {
        let s = max(0, Int(self))
        return String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
    }
}
