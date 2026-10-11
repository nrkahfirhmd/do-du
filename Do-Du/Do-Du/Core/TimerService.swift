import Foundation
import SwiftData

enum TimerService {
    static func running(in context: ModelContext) -> [TimeEntry] {
        (try? context.fetch(FetchDescriptor<TimeEntry>(predicate: #Predicate { $0.end == nil }))) ?? []
    }

    static func current(in context: ModelContext) -> TimeEntry? {
        running(in: context).max { $0.start < $1.start }
    }

    /// Stops whatever is running at the same instant, then starts `task`.
    static func start(_ task: TaskItem?, project: Project? = nil, in context: ModelContext, at now: Date = .now) {
        for entry in running(in: context) { entry.end = now }
        context.insert(TimeEntry(task: task, project: project, start: now))
        try? context.save()
        onChange?(now)
    }

    static func stop(in context: ModelContext, at now: Date = .now) {
        for entry in running(in: context) { entry.end = max(now, entry.start) }
        try? context.save()
        onChange?(nil)
    }

    static func toggleQuick(project: Project? = nil, in context: ModelContext) {
        if current(in: context) != nil { stop(in: context) } else { start(nil, project: project, in: context) }
    }

    static func toggle(_ task: TaskItem, in context: ModelContext) {
        if current(in: context)?.task == task { stop(in: context) } else { start(task, in: context) }
    }

    /// Offline starts on two devices: keep the latest, stop the others at its start.
    static func resolveConflicts(in context: ModelContext) {
        let entries = running(in: context)
        guard entries.count > 1, let keep = DayMath.runningToKeep(entries.map(\.start)) else { return }
        let cutoff = entries[keep].start
        for (i, entry) in entries.enumerated() where i != keep { entry.end = max(cutoff, entry.start) }
        try? context.save()
    }

    /// Hook for side effects (long-run notification). Called with the new start date, or nil on stop.
    static var onChange: ((Date?) -> Void)?
}
