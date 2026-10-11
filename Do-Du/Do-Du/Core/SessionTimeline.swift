import Foundation

struct SessionBlock: Equatable {
    var start: Double
    var end: Double
    /// Order of the session's project among today's projects (0 = first); nil = No project.
    var projectRank: Int?
    var isLive: Bool
}

enum SessionTimeline {
    /// `hours`-long window that ends at the next full hour after `now`.
    static func window(now: Date, hours: Int = 4, calendar: Calendar = .current) -> DateInterval {
        let hourStart = calendar.dateInterval(of: .hour, for: now)!.start
        let end = calendar.date(byAdding: .hour, value: 1, to: hourStart)!
        return DateInterval(start: calendar.date(byAdding: .hour, value: -hours, to: end)!, end: end)
    }

    static func labels(for window: DateInterval, calendar: Calendar = .current) -> [String] {
        var out: [String] = []
        var t = window.start
        while t <= window.end {
            out.append("\(calendar.component(.hour, from: t)):00")
            t = calendar.date(byAdding: .hour, value: 1, to: t)!
        }
        return out
    }

    /// Clips sessions to the window. Running sessions end at `now`. Ranks follow `projectOrder`.
    static func blocks(_ sessions: [(start: Date, end: Date?, projectID: String?)],
                       window: DateInterval, now: Date, projectOrder: [String]) -> [SessionBlock] {
        let total = window.duration
        guard total > 0 else { return [] }
        return sessions.compactMap { s in
            let end = s.end ?? now
            let a = max(s.start, window.start), b = min(end, window.end)
            guard b > a else { return nil }
            return SessionBlock(start: a.timeIntervalSince(window.start) / total,
                                end: b.timeIntervalSince(window.start) / total,
                                projectRank: s.projectID.flatMap { projectOrder.firstIndex(of: $0) },
                                isLive: s.end == nil)
        }
    }

    static func nowFraction(_ now: Date, window: DateInterval) -> Double {
        min(1, max(0, now.timeIntervalSince(window.start) / window.duration))
    }
}
