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

try checkModelRoundTrip()
print("All checks passed")
