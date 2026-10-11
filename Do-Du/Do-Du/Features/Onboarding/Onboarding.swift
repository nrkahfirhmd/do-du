import Foundation

enum OnboardingStep: Int, CaseIterable {
    case welcome, project, days, dayStart, sync, done
}

struct OnboardingAnswers: Equatable {
    var name = ""
    var colorName = "forest"
    var targetMinutes = 180
    /// Monday first, as the screens show them.
    var days = [Bool](repeating: true, count: 7)
    var dayStart = 0
    var iCloud = true
    var key = ""

    static let suggestions = ["Client work", "Thesis", "Side project", "Writing"]
    static let presets: [(label: String, days: [Bool])] = [
        ("Every day", [true, true, true, true, true, true, true]),
        ("Weekdays", [true, true, true, true, true, false, false]),
        ("Weekends", [false, false, false, false, false, true, true]),
    ]
    static let dayLetters = ["M", "T", "W", "T", "F", "S", "S"]
    static let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var projectName: String { trimmedName.isEmpty ? "Your project" : trimmedName }
    var dayCount: Int { days.filter { $0 }.count }

    func canContinue(_ step: OnboardingStep) -> Bool {
        switch step {
        case .project: !trimmedName.isEmpty
        case .days: dayCount > 0
        default: true
        }
    }

    mutating func stepTarget(by delta: Int) {
        targetMinutes = min(720, max(15, targetMinutes + delta))
    }

    /// `Project.activeWeekdaysMask`: bit 0 = Sunday (Calendar order).
    var weekdayMask: Int {
        days.enumerated().reduce(0) { mask, d in
            d.element ? mask | 1 << ((d.offset + 1) % 7) : mask
        }
    }

    /// Monday-first index of a Calendar weekday (1 = Sunday).
    static func mondayIndex(_ weekday: Int) -> Int { (weekday + 5) % 7 }

    func isRestDay(weekday: Int) -> Bool { !days[Self.mondayIndex(weekday)] }

    func nextScheduledDay(after weekday: Int) -> String? {
        let start = Self.mondayIndex(weekday)
        return (1...7).map { (start + $0) % 7 }.first { days[$0] }.map { Self.dayNames[$0] }
    }

    var daysLabel: String {
        if dayCount == 7 { return "Every day" }
        if days == Self.presets[1].days { return "Weekdays" }
        if days == Self.presets[2].days { return "Weekends" }
        if dayCount == 0 { return "No days" }
        return Self.dayNames.indices.filter { days[$0] }.map { String(Self.dayNames[$0].prefix(3)) }
            .joined(separator: ", ")
    }

    var weekNote: String {
        guard dayCount > 0 else { return "Pick at least one day." }
        let count = dayCount == 7 ? "Every day" : "\(dayCount) day\(dayCount == 1 ? "" : "s")"
        return "\(count) · \(Self.hm(targetMinutes * dayCount)) a week"
    }

    var dayRange: String { dayStart == 0 ? "Midnight to midnight" : "\(dayStart):00 → \(dayStart):00 next day" }

    var dayStartNote: String {
        dayStart == 0
            ? "Your day starts at midnight. Work after 0:00 counts toward the new day."
            : "Work before \(dayStart):00 counts toward the day before, so a session at \(dayStart - 1):30 on Monday night still counts for Monday."
    }

    func verdict(weekday: Int) -> (String, String, String) {
        if isRestDay(weekday: weekday) {
            let next = nextScheduledDay(after: weekday).map { " Your first target starts \($0)." } ?? ""
            return ("Today is a ", "rest day", "." + next)
        }
        return ("You need ", Self.hm(targetMinutes), " to call it a day.")
    }

    static func hm(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        return h == 0 ? "\(m)m" : m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }
}
