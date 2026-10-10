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
    static func day(_ date: Date, calendar: Calendar = .current) -> DateInterval {
        calendar.dateInterval(of: .day, for: date)!
    }

    /// Seconds of `[start, end)` that fall inside `range`. Splits entries across midnight for free.
    static func overlap(start: Date, end: Date, with range: DateInterval) -> TimeInterval {
        max(0, min(end, range.end).timeIntervalSince(max(start, range.start)))
    }

    /// `mask` bit `n` = Calendar weekday `n + 1` (1 = Sunday).
    static func isActive(mask: Int, on date: Date, calendar: Calendar = .current) -> Bool {
        mask & (1 << (calendar.component(.weekday, from: date) - 1)) != 0
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
