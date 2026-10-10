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

func checkClaudeClient() throws {
    let req = ClaudeRequest(system: "sys", messages: [["role": "user", "content": "hi"]],
                            tools: [["name": "t", "input_schema": ["type": "object"]]],
                            effort: "medium", schema: ["type": "object"])
    let body = ClaudeClient.body(req)
    precondition(body["model"]?.string == "claude-opus-5-5", "model")
    precondition(body["max_tokens"]?.int == 16000, "max_tokens")
    precondition(body["fallbacks"]?.string == "default", "fallbacks")
    precondition(body["output_config"]?["effort"]?.string == "medium", "effort")
    precondition(body["output_config"]?["format"]?["type"]?.string == "json_schema", "schema")
    precondition(body["system"]?.array?.first?["cache_control"]?["type"]?.string == "ephemeral", "cache")
    let encoded = String(decoding: body.encoded(), as: UTF8.self)
    precondition(encoded.contains("\"max_tokens\":16000"), "ints encode without .0")

    let text = try ClaudeClient.parse(Data(#"{"content":[{"type":"thinking","thinking":"","signature":"abc"},{"type":"text","text":"Hello"}],"stop_reason":"end_turn"}"#.utf8))
    precondition(text.text == "Hello" && text.content.count == 2, "text + thinking kept for echo")

    let tool = try ClaudeClient.parse(Data(#"{"content":[{"type":"tool_use","id":"tu1","name":"time_summary","input":{"start":"2026-10-01"}}],"stop_reason":"tool_use"}"#.utf8))
    precondition(tool.toolUses == [ToolUse(id: "tu1", name: "time_summary", input: ["start": "2026-10-01"])], "tool_use")

    var refused = false
    do { _ = try ClaudeClient.parse(Data(#"{"content":[],"stop_reason":"refusal"}"#.utf8)) } catch ClaudeError.refused { refused = true }
    precondition(refused, "refusal")
    print("✓ Claude request body + response parsing")
}

func checkSnapshot() throws {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    let iso = ISO8601DateFormatter()
    func d(_ s: String) -> Date { iso.date(from: s)! }
    let ctx = ModelContext(try ModelContainer(for: Schema(allModels), configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    let p = Project(name: "Do-Du", dailyTargetMinutes: 60, activeWeekdaysMask: Weekdays.monToFri)
    let a = TaskItem(title: "Spec", project: p), b = TaskItem(title: "Ship", project: p)
    b.dueDate = d("2026-10-13T00:00:00Z"); b.estimateMinutes = 30
    a.setDone(true); a.completedAt = d("2026-10-12T15:00:00Z")
    [p].forEach(ctx.insert); [a, b].forEach(ctx.insert)
    ctx.insert(TimeEntry(task: a, start: d("2026-10-12T09:00:00Z"), end: d("2026-10-12T10:30:00Z")))
    ctx.insert(TimeEntry(task: nil, start: d("2026-10-12T11:00:00Z"), end: d("2026-10-12T11:20:00Z")))
    try ctx.save()
    let now = d("2026-10-13T08:00:00Z")
    let snap = AISnapshot(projects: [p], entries: try ctx.fetch(FetchDescriptor<TimeEntry>()), tasks: [a, b],
                          range: DateInterval(start: d("2026-10-12T00:00:00Z"), end: d("2026-10-14T00:00:00Z")),
                          now: now, calendar: cal)
    let t = snap.text
    precondition(t.contains("- Do-Du: 60m/day · Mon Tue Wed Thu Fri"), "project line")
    precondition(t.contains("Tracked in range:\n- Do-Du: 90m"), "tracked")
    precondition(t.contains("No project (not counted toward targets): 20m"), "no project")
    precondition(t.contains("2026-10-12 Mon: enough | Do-Du 90/60"), "day verdict")
    precondition(t.contains("2026-10-13 Tue: not enough (60m short) | Do-Du 0/60"), "today")
    precondition(!t.contains("2026-10-14"), "future days omitted")
    precondition(t.contains("[0] Ship · Do-Du · due 2026-10-13 Tue · est 30m"), "open task")
    precondition(t.contains("- Spec · Do-Du · 2026-10-12 Mon"), "completed")
    precondition(snap.openTasks == [b], "index map")
    print("✓ AI snapshot")
}

func checkQuickAddMapping() throws {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    let p = Project(name: "Do-Du"), c = Category(name: "Deep Work")
    let now = ISO8601DateFormatter().date(from: "2026-10-12T15:00:00Z")!
    let hit = QuickAddParser.prefill(from: TaskDraft(title: " Design review ", project: "do-du", category: "deep work",
                                                     dueInDays: 1, estimateMinutes: 120),
                                     projects: [p], categories: [c], now: now, calendar: cal)
    precondition(hit.title == "Design review" && hit.project === p && hit.category === c, "case-insensitive match")
    precondition(hit.dueDate == ISO8601DateFormatter().date(from: "2026-10-13T00:00:00Z"), "tomorrow at start of day")
    precondition(hit.estimateMinutes == 120, "estimate")
    let miss = QuickAddParser.prefill(from: TaskDraft(title: "Call", project: "Unknown", category: "",
                                                      dueInDays: -1, estimateMinutes: 0),
                                      projects: [p], categories: [c], now: now, calendar: cal)
    precondition(miss.project == nil && miss.category == nil && miss.dueDate == nil && miss.estimateMinutes == nil,
                 "unknown project never guessed")
    print("✓ quick add mapping")
}

func checkDayStartHour() throws {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    let iso = ISO8601DateFormatter()
    func d(_ s: String) -> Date { iso.date(from: s)! }
    // 02:00 Tuesday with a 3:00 day start still belongs to Monday.
    let late = d("2026-10-13T02:00:00Z")
    precondition(DayMath.logicalDate(late, calendar: cal, startHour: 3) == d("2026-10-12T00:00:00Z"), "late night → previous day")
    precondition(DayMath.day(late, calendar: cal, startHour: 3) == DateInterval(start: d("2026-10-12T03:00:00Z"), end: d("2026-10-13T03:00:00Z")), "shifted interval")
    precondition(DayMath.day(late, calendar: cal, startHour: 0).start == d("2026-10-13T00:00:00Z"), "default midnight")
    let week = DayMath.period(.weekOfYear, for: late, calendar: cal, startHour: 3)
    precondition(DayMath.logicalDates(in: week, calendar: cal, startHour: 3).count == 7, "7 days in week")
    print("✓ day start hour")
}

func checkPlanMapping() throws {
    let ctx = ModelContext(try ModelContainer(for: Schema(allModels), configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    let p = Project(name: "P")
    let a = TaskItem(title: "a", project: p), b = TaskItem(title: "b", project: p), old = TaskItem(title: "old", project: p)
    ctx.insert(p); [a, b, old].forEach(ctx.insert)
    let json = #"{"items":[{"task":1,"minutes":2000,"reason":"due"},{"task":7,"minutes":30,"reason":"x"},{"task":1,"minutes":30,"reason":"dup"},{"task":0,"minutes":1,"reason":"short"}],"note":"ok"}"#
    let parsed = DayPlanner.items(from: json, openTasks: [a, b])!
    precondition(parsed.items.map(\.task) == [b, a], "unknown + duplicate indexes dropped, order kept")
    precondition(parsed.items.map(\.minutes) == [600, 5], "minutes clamped")
    precondition(parsed.note == "ok", "note")
    precondition(DayPlanner.items(from: "not json", openTasks: [a]) == nil, "bad json")

    let now = Date.now
    old.plannedFor = DayMath.logicalDate(now)
    DayPlanner.accept(parsed.items, allTasks: [a, b, old], now: now)
    precondition(old.plannedFor == nil, "previous plan cleared")
    precondition(b.plannedFor == DayMath.logicalDate(now) && b.planOrder == 0 && a.planOrder == 1 && a.plannedMinutes == 5, "plan written in order")
    print("✓ plan mapping + accept")
}

func checkChatTools() throws {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    let iso = ISO8601DateFormatter()
    func d(_ s: String) -> Date { iso.date(from: s)! }
    let ctx = ModelContext(try ModelContainer(for: Schema(allModels), configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    let p = Project(name: "Do-Du", dailyTargetMinutes: 60, activeWeekdaysMask: Weekdays.all), c = Category(name: "Deep Work")
    let t = TaskItem(title: "Spec", project: p, category: c)
    t.dueDate = d("2026-10-13T00:00:00Z")
    ctx.insert(p); ctx.insert(c); ctx.insert(t)
    ctx.insert(TimeEntry(task: t, start: d("2026-10-12T09:00:00Z"), end: d("2026-10-12T10:00:00Z")))
    ctx.insert(TimeEntry(task: nil, start: d("2026-10-12T11:00:00Z"), end: d("2026-10-12T11:30:00Z")))
    try ctx.save()
    let tools = ChatTools(projects: [p], entries: try ctx.fetch(FetchDescriptor<TimeEntry>()), tasks: [t],
                          now: d("2026-10-13T12:00:00Z"), calendar: cal)
    func call(_ name: String, _ input: JSON) -> (result: String, isError: Bool) { tools.run(ToolUse(id: "x", name: name, input: input)) }

    let byProject = call("time_summary", ["start": "2026-10-12", "end": "2026-10-12", "group_by": "project"])
    precondition(!byProject.isError && byProject.result == "Do-Du: 60m\nNo project: 30m\nTotal: 90m", "by project")
    let byCat = call("time_summary", ["start": "2026-10-12", "end": "2026-10-13", "group_by": "category"])
    precondition(byCat.result.contains("Deep Work: 60m") && byCat.result.contains("Uncategorized: 30m"), "by category")
    let byDay = call("time_summary", ["start": "2026-10-12", "end": "2026-10-13", "group_by": "day"])
    precondition(byDay.result == "2026-10-12: 90m\n2026-10-13: 0m", "by day")
    let verdicts = call("day_verdicts", ["start": "2026-10-12", "end": "2026-10-14"])
    precondition(verdicts.result == "2026-10-12: enough | Do-Du 60/60\n2026-10-13: not enough (60m short) | Do-Du 0/60", "verdicts, future skipped")
    let list = call("list_tasks", ["status": "open", "project": "do-du", "due_before": "2026-10-13"])
    precondition(list.result == "Spec · Do-Du · Deep Work · due 2026-10-13", "list tasks")
    precondition(call("time_summary", ["start": "bad", "end": "2026-10-12", "group_by": "day"]).isError, "bad date is_error")
    precondition(call("delete_everything", [:]).isError, "unknown tool")
    print("✓ chat tools")
}

func checkCSV() throws {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    let iso = ISO8601DateFormatter()
    let ctx = ModelContext(try ModelContainer(for: Schema(allModels), configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    let p = Project(name: "Client, Inc"), t = TaskItem(title: "Say \"hi\"", project: p)
    ctx.insert(p); ctx.insert(t)
    let e = TimeEntry(task: t, start: iso.date(from: "2026-10-12T09:00:00Z")!, end: iso.date(from: "2026-10-12T09:45:00Z")!)
    ctx.insert(e)
    let csv = TimeEntryCSV.make([e], calendar: cal)
    precondition(csv == "date,start,end,minutes,project,task,category\n2026-10-12,2026-10-12T09:00:00Z,2026-10-12T09:45:00Z,45,\"Client, Inc\",\"Say \"\"hi\"\"\",\n", "csv quoting")
    print("✓ CSV export")
}

func checkIdleStop() throws {
    let now = Date(timeIntervalSince1970: 3_000_000)
    precondition(IdleStop.stopDate(now: now, idleSeconds: 599, thresholdSeconds: 600) == nil, "below threshold keeps running")
    precondition(IdleStop.stopDate(now: now, idleSeconds: 600, thresholdSeconds: 600) == now.addingTimeInterval(-600), "backdates to last activity")
    precondition(IdleStop.stopDate(now: now, idleSeconds: 3600, thresholdSeconds: 600) == now.addingTimeInterval(-3600), "long idle backdates fully")
    precondition(IdleStop.stopDate(now: now, idleSeconds: 600, thresholdSeconds: 0) == nil, "zero threshold never stops")
    print("✓ idle stop date")
}

func checkSharedStore() throws {
    let fm = FileManager.default
    let group = fm.temporaryDirectory.appendingPathComponent("dodu-group-\(UUID())")
    let url = SharedStore.storeURL(groupURL: group)!
    precondition(url.lastPathComponent == "Do-Du.store", "group file name")
    precondition(SharedStore.storeURL(groupURL: nil) == nil, "nil group → nil (fallback)")
    precondition(SharedStore.legacyStoreURL(appSupport: group).lastPathComponent == "default.store", "legacy name")

    // Moves legacy + wal/shm once; second run is a no-op.
    let legacyDir = fm.temporaryDirectory.appendingPathComponent("dodu-legacy-\(UUID())")
    try fm.createDirectory(at: legacyDir, withIntermediateDirectories: true)
    let legacy = legacyDir.appendingPathComponent("default.store")
    try "x".write(to: legacy, atomically: true, encoding: .utf8)
    try "w".write(to: URL(fileURLWithPath: legacy.path + "-wal"), atomically: true, encoding: .utf8)
    let target = group.appendingPathComponent("Do-Du.store")
    precondition(SharedStore.migrate(from: legacy, to: target, fileManager: fm) == target, "migrates")
    precondition(fm.fileExists(atPath: target.path) && fm.fileExists(atPath: target.path + "-wal"), "wal moved")
    precondition(!fm.fileExists(atPath: legacy.path), "legacy gone")
    precondition(SharedStore.migrate(from: legacy, to: target, fileManager: fm) == nil, "no-op when target exists")
    print("✓ shared store location + migration")
}

func checkIntents() throws {
    let ctx = ModelContext(try ModelContainer(for: Schema(allModels), configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    let p = Project(name: "P")
    let t = TaskItem(title: "Deep work", project: p)
    ctx.insert(p); ctx.insert(t)
    try ctx.save()
    let entity = TaskItemEntity(id: TaskItemEntity.id(for: t.persistentModelID), title: t.title, projectName: "P")
    let back = TaskItemEntity.pid(from: entity.id)
    precondition(back == t.persistentModelID, "entity id round-trips to the same task")
    precondition(TaskItemEntity.pid(from: "!!!") == nil, "garbage id resolves to nil")
    // Resolution the way queries do it: match open tasks by identifier.
    let open = try ctx.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { !$0.isDone }))
    precondition(open.first { $0.persistentModelID == back }?.title == "Deep work", "query resolves")
    print("✓ intent entities")
}

func checkMeetings() throws {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    func d(_ s: String) -> Date { ISO8601DateFormatter().date(from: s)! }
    precondition(DayPlanner.meetingsLine([]) == nil, "free day")
    let line = DayPlanner.meetingsLine([
        (title: "Standup", start: d("2026-10-13T09:00:00Z"), end: d("2026-10-13T09:30:00Z")),
        (title: "Review", start: d("2026-10-13T14:00:00Z"), end: d("2026-10-13T15:00:00Z")),
    ])!
    precondition(line.contains("1h 30m"), "totaled")
    precondition(line.contains("Standup") || line.contains("09:00"), "lists meetings")
    print("✓ meetings line")
}

func checkNotion() throws {    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!

    // Database ID forms.
    let plain = "a1b2c3d4e5f60718293a4b5c6d7e8f90"
    precondition(NotionClient.normalizeDatabaseID(plain) == plain, "bare id")
    precondition(NotionClient.normalizeDatabaseID("a1b2c3d4-e5f6-0718-293a-4b5c6d7e8f90") == plain, "hyphenated")
    precondition(NotionClient.normalizeDatabaseID("https://www.notion.so/My-Tasks-\(plain)?v=deadbeefdeadbeefdeadbeefdeadbeef") == plain, "url")
    precondition(NotionClient.normalizeDatabaseID("xyz") == "", "garbage rejected")

    // Request body + error mapping.
    let body = NotionClient.queryBody(cursor: nil)
    precondition(body["page_size"]?.int == 100 && body["start_cursor"] == nil, "first page")
    precondition(NotionClient.queryBody(cursor: "c")["start_cursor"]?.string == "c", "cursor")
    precondition(NotionClient.error(status: 401, json: ["code": "unauthorized"]) == .badToken, "401")
    precondition(NotionClient.error(status: 404, json: ["code": "object_not_found"]) == .notFound, "404")
    precondition(NotionClient.error(status: 429, json: ["code": "rate_limited"]) == .rateLimited, "429")

    // Response with checkbox, status, date and select schemas.
    let data = Data("""
        {"has_more": true, "next_cursor": "next",
         "results": [
          {"id": "p1", "properties": {
            "Name": {"type": "title", "title": [{"plain_text": "Write spec"}]},
            "Done": {"type": "checkbox", "checkbox": true},
            "Due": {"type": "date", "date": {"start": "2026-10-15"}},
            "Project": {"type": "select", "select": {"name": "Do-Du"}}}},
          {"id": "p2", "properties": {
            "Title": {"type": "title", "title": [{"plain_text": "Ship "}, {"plain_text": "it"}]},
            "State": {"type": "status", "status": {"name": "In progress"}},
            "When": {"type": "date", "date": {"start": "2026-10-15T09:00:00.000Z"}}}},
          {"id": "p3", "properties": {
            "Name": {"type": "title", "title": []},
            "Done": {"type": "checkbox", "checkbox": true}}}]}
        """.utf8)
    let result = try NotionClient.parse(data, calendar: cal)
    precondition(result.nextCursor == "next", "pagination cursor")
    precondition(result.pages.count == 2, "empty title skipped")
    let first = result.pages[0]
    precondition(first.title == "Write spec" && first.isDone && first.projectName == "Do-Du", "checkbox row")
    precondition(first.dueDate == cal.date(from: DateComponents(year: 2026, month: 10, day: 15)), "date-only due")
    let second = result.pages[1]
    precondition(second.title == "Ship it" && !second.isDone && second.projectName == nil, "status row")

    // Apply: insert new, refresh linked, skip unknown project.
    let ctx = ModelContext(try ModelContainer(for: Schema(allModels), configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    let p = Project(name: "Do-Du")
    let old = TaskItem(title: "Stale", project: p)
    old.externalSource = "notion"; old.externalID = "p1"
    ctx.insert(p); ctx.insert(old)
    let drafts = [
        ExternalDraft(source: "notion", externalID: "p1", title: "Write spec", isDone: true,
                      dueDate: cal.date(from: DateComponents(year: 2026, month: 10, day: 15)), projectName: "Do-Du"),
        ExternalDraft(source: "notion", externalID: "p2", title: "Ship it", isDone: false,
                      dueDate: nil, projectName: "do-du"),
        ExternalDraft(source: "notion", externalID: "p9", title: "Orphan", isDone: false,
                      dueDate: nil, projectName: "Unknown"),
    ]
    let r = NotionClient.apply(drafts, projects: [p], in: ctx)
    precondition(r == (1, 1, 1), "inserted, updated, skipped")
    precondition(old.title == "Write spec" && old.isDone && old.completedAt != nil, "linked refreshed")
    let fresh = (try ctx.fetch(FetchDescriptor<TaskItem>())).first { $0.externalID == "p2" }
    precondition(fresh?.project === p && fresh?.isDone == false, "case-insensitive project match")
    print("✓ notion import")
}

func checkRemindersImport() throws {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    let d = RemindersSource.draft(id: "r1", title: "  Pay rent ", isDone: false,
                                  due: DateComponents(year: 2026, month: 10, day: 31, hour: 9),
                                  list: "Home", calendar: cal)!
    precondition(d.source == "reminders" && d.title == "Pay rent" && d.projectName == "Home", "mapping")
    precondition(d.dueDate == ISO8601DateFormatter().date(from: "2026-10-31T00:00:00Z"), "due at start of day")
    precondition(RemindersSource.draft(id: "r2", title: "   ", isDone: false, due: nil, list: nil, calendar: cal) == nil, "untitled skipped")

    let ctx = ModelContext(try ModelContainer(for: Schema(allModels), configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    let home = Project(name: "home")
    ctx.insert(home)
    let done = ExternalDraft(source: "reminders", externalID: "r3", title: "Old", isDone: true, dueDate: nil, projectName: "Home")
    // Import: list "Home" matches project "home"; finished reminders are not offered as new.
    let split1 = RemindersSource.split([d, done], tasks: [])
    precondition(split1.new.map(\.externalID) == ["r1"] && split1.linked.isEmpty, "done not offered")
    let r1 = RemindersSource.apply(split1.new, projects: [home], in: ctx)
    precondition(r1.inserted == 1, "inserted")
    // Later the reminder is completed in Reminders: it's linked now and refreshes.
    var completed = d
    completed.isDone = true
    let tasks = try ctx.fetch(FetchDescriptor<TaskItem>())
    let split2 = RemindersSource.split([completed], tasks: tasks)
    precondition(split2.new.isEmpty && split2.linked.count == 1, "linked")
    let r2 = RemindersSource.apply(split2.new + split2.linked, projects: [home], in: ctx)
    precondition(r2.updated == 1 && tasks[0].isDone, "linked task refreshed")
    // Same external ID from Notion would be a different link.
    precondition(NotionClient.split([d], tasks: tasks).new.count == 1, "links are per source")
    print("✓ reminders import")
}

func checkDesignFoundation() throws {
    // Palette: old names land on redesign swatches; new names pass through.
    precondition(Palette.canonical("blue") == "forest" && Palette.canonical("green") == "sage", "old names")
    precondition(Palette.canonical("orange") == "pine" && Palette.canonical("purple") == "slate", "old names 2")
    precondition(Palette.names.allSatisfy { Palette.canonical($0) == $0 }, "new names stable")
    precondition(Palette.canonical("nonsense") == "forest", "unknown → forest")

    // Session strip: 4h window ending at the next full hour.
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    let iso = ISO8601DateFormatter()
    func d(_ s: String) -> Date { iso.date(from: s)! }
    let now = d("2026-10-12T09:30:00Z")
    let w = SessionTimeline.window(now: now, calendar: cal)
    precondition(w.start == d("2026-10-12T06:00:00Z") && w.end == d("2026-10-12T10:00:00Z"), "window")
    precondition(SessionTimeline.labels(for: w, calendar: cal) == ["6:00", "7:00", "8:00", "9:00", "10:00"], "labels")
    precondition(SessionTimeline.nowFraction(now, window: w) == 0.875, "now line")
    let blocks = SessionTimeline.blocks([
        (d("2026-10-12T05:00:00Z"), d("2026-10-12T07:00:00Z"), "A"),   // clipped at window start
        (d("2026-10-12T08:00:00Z"), d("2026-10-12T08:30:00Z"), nil),   // No project
        (d("2026-10-12T09:00:00Z"), nil, "B"),                         // live, ends at now
        (d("2026-10-12T03:00:00Z"), d("2026-10-12T04:00:00Z"), "A"),   // outside → dropped
    ], window: w, now: now, projectOrder: ["A", "B"])
    precondition(blocks == [
        SessionBlock(start: 0, end: 0.25, projectRank: 0, isLive: false),
        SessionBlock(start: 0.5, end: 0.625, projectRank: nil, isLive: false),
        SessionBlock(start: 0.75, end: 0.875, projectRank: 1, isLive: true),
    ], "blocks")
    print("✓ design palette + session strip")
}

try checkModelRoundTrip()
try checkDayMath()
try checkTimer()
try checkQuickTimer()
try checkClaudeClient()
try checkSnapshot()
try checkQuickAddMapping()
try checkDayStartHour()
try checkPlanMapping()
try checkChatTools()
try checkCSV()
try checkIdleStop()
try checkSharedStore()
try checkNotion()
try checkMeetings()
try checkIntents()
try checkRemindersImport()
try checkDesignFoundation()
print("All checks passed")
