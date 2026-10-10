// Standalone self-checks for Do-Du core logic. Run: checks/run.sh
import Foundation
import SwiftData

func checkModelRoundTrip() throws {
    let container = try ModelContainer(for: Schema(allModels),
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let ctx = container.mainContext
    let p = Project(name: "Do-Du", dailyTargetMinutes: 120)
    let t = TaskItem(title: "Write spec", project: p)
    ctx.insert(p); ctx.insert(t)
    ctx.insert(TimeEntry(task: t, start: .now.addingTimeInterval(-60), end: .now))
    try ctx.save()

    let fetched = try ctx.fetch(FetchDescriptor<Project>())
    precondition(fetched.count == 1 && fetched[0].tasks?.first?.entries?.count == 1, "round trip")

    ctx.delete(fetched[0]); try ctx.save()
    let left = try ctx.fetchCount(FetchDescriptor<TimeEntry>())
    precondition(left == 0, "cascade delete")
    print("✓ model round trip + cascade")
}

func checkDayMath() throws {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    let iso = ISO8601DateFormatter()
    func d(_ s: String) -> Date { iso.date(from: s)! }
    let monday = d("2026-10-12T12:00:00Z"), saturday = d("2026-10-10T12:00:00Z")
    let mon = DayMath.day(monday, calendar: cal)

    // Midnight split: 23:00 Sun → 01:00 Mon gives 1h to Monday.
    precondition(DayMath.overlap(start: d("2026-10-11T23:00:00Z"), end: d("2026-10-12T01:00:00Z"), with: mon) == 3600, "midnight split")

    // Weekday mask.
    precondition(DayMath.isActive(mask: Weekdays.monToFri, on: monday, calendar: cal), "monday active")
    precondition(!DayMath.isActive(mask: Weekdays.monToFri, on: saturday, calendar: cal), "saturday inactive")

    // Verdicts.
    precondition(DayMath.verdict([]) == .restDay, "rest day")
    precondition(DayMath.verdict([(3600, 3600)]) == .enough, "exactly met")
    precondition(DayMath.verdict([(1800, 3600), (7200, 3600)]) == .notYet(remaining: 1800), "over-target does not offset others")

    // Model-level: running entry counts to now; archived and weekend projects excluded.
    let container = try ModelContainer(for: Schema(allModels), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let ctx = container.mainContext
    let p = Project(name: "A", dailyTargetMinutes: 60), archived = Project(name: "B", dailyTargetMinutes: 60)
    archived.isArchived = true
    let t = TaskItem(title: "t", project: p)
    [p, archived].forEach(ctx.insert); ctx.insert(t)
    ctx.insert(TimeEntry(task: t, start: d("2026-10-12T09:00:00Z")))  // running
    try ctx.save()
    let now = d("2026-10-12T09:30:00Z")
    precondition(p.tracked(in: mon, now: now) == 1800, "running entry counts to now")
    precondition(Stats.verdict(for: [p, archived], on: monday, now: now, calendar: cal) == .notYet(remaining: 1800), "archived excluded")
    precondition(Stats.verdict(for: [p], on: d("2026-10-12T10:00:00Z"), now: d("2026-10-12T10:00:00Z"), calendar: cal) == .enough, "met later")
    precondition(Stats.verdict(for: [p], on: saturday, calendar: cal) == .restDay, "weekend rest day")

    // Overlap detection and running-timer conflict rule.
    let spans = [(start: d("2026-10-12T09:00:00Z"), end: d("2026-10-12T10:00:00Z"))]
    precondition(DayMath.firstConflict(start: d("2026-10-12T10:00:00Z"), end: d("2026-10-12T11:00:00Z"), in: spans) == nil, "touching ok")
    precondition(DayMath.firstConflict(start: d("2026-10-12T09:59:00Z"), end: d("2026-10-12T11:00:00Z"), in: spans) == 0, "overlap caught")
    precondition(DayMath.runningToKeep([d("2026-10-12T09:00:00Z"), d("2026-10-12T09:05:00Z")]) == 1, "latest start wins")
    print("✓ day math + verdicts + conflicts")
}

func checkTimer() throws {
    let url = FileManager.default.temporaryDirectory.appending(path: "dodu-timer-check-\(UUID()).store")
    func open() throws -> ModelContext {
        ModelContext(try ModelContainer(for: Schema(allModels), configurations: ModelConfiguration(url: url)))
    }
    var ctx = try open()
    let p = Project(name: "P"), a = TaskItem(title: "a", project: p), b = TaskItem(title: "b", project: p)
    ctx.insert(p); ctx.insert(a); ctx.insert(b)
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    // Switching tasks closes the old entry at the same instant.
    TimerService.start(a, in: ctx, at: t0)
    TimerService.start(b, in: ctx, at: t0 + 600)
    let running = TimerService.running(in: ctx)
    precondition(running.count == 1 && running[0].task == b, "one running timer")
    precondition(a.entries?.first?.end == t0 + 600, "old timer stopped at switch")

    // Relaunch: running entry and its start survive.
    ctx = try open()
    let reopened = TimerService.running(in: ctx)
    precondition(reopened.count == 1 && reopened[0].start == t0 + 600, "running survives relaunch")

    // Sync conflict: two running entries → latest start kept, other closed at that start.
    let bb = reopened[0].task!
    ctx.insert(TimeEntry(task: bb, start: t0 + 900))
    try ctx.save()
    TimerService.resolveConflicts(in: ctx)
    let after = TimerService.running(in: ctx)
    precondition(after.count == 1 && after[0].start == t0 + 900, "latest start wins")
    precondition(reopened[0].end == t0 + 900, "older closed at newer start")

    TimerService.stop(in: ctx, at: t0 + 1200)
    precondition(TimerService.running(in: ctx).isEmpty, "stop")
    print("✓ timer switch, relaunch, conflict resolution")
}

func checkQuickTimer() throws {
    let ctx = ModelContext(try ModelContainer(for: Schema(allModels), configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    let p = Project(name: "P", dailyTargetMinutes: 30, activeWeekdaysMask: Weekdays.all), t = TaskItem(title: "t", project: p)
    ctx.insert(p); ctx.insert(t)
    let t0 = Date(timeIntervalSince1970: 2_000_000)
    let day = DayMath.day(t0)

    // Quick timer with no project: tracked, but counts toward no project.
    TimerService.start(nil, in: ctx, at: t0)
    TimerService.start(nil, project: p, in: ctx, at: t0 + 600)   // switch: closes the first
    let first = try ctx.fetch(FetchDescriptor<TimeEntry>(predicate: #Predicate { $0.project == nil && $0.task == nil }))
    precondition(first.count == 1 && first[0].end == t0 + 600, "quick timer switch")
    precondition(p.tracked(in: day, now: t0 + 1200) == 600, "project quick entry counts toward project")

    // Assigning the loose entry later moves its time to the project.
    first[0].project = p
    try ctx.save()
    precondition(p.tracked(in: day, now: t0 + 1200) == 1200, "assigned later counts")

    // Starting a task timer stops the quick one; entry from task does not set project.
    TimerService.start(t, in: ctx, at: t0 + 1200)
    precondition(TimerService.running(in: ctx).first?.task == t, "task timer replaces quick")
    precondition(t.entries?.first?.project == nil, "task entries derive project from task")
    precondition(p.tracked(in: day, now: t0 + 1800) == 1800, "all three count once")

    // Deleting the project removes its loose entries too.
    ctx.delete(p); try ctx.save()
    let remaining = try ctx.fetchCount(FetchDescriptor<TimeEntry>())
    precondition(remaining == 0, "cascade loose entries")
    print("✓ quick timer without task")
}

try checkModelRoundTrip()
try checkDayMath()
try checkTimer()
try checkQuickTimer()
print("All checks passed")
