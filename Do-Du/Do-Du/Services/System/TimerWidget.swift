import Foundation
import SwiftData
import WidgetKit

enum TimerWidget {
    static func register(container: ModelContainer) {
        let previous = TimerService.onChange
        TimerService.onChange = { start in
            previous?(start)
            WidgetCenter.shared.reloadAllTimelines()
            #if os(iOS)
            syncLiveActivity(container: container)
            #endif
        }
        #if os(iOS)
        syncLiveActivity(container: container)
        #endif
    }

    #if os(iOS)
    @MainActor static func syncLiveActivity(container: ModelContainer) {
        LiveTimer.sync(container: container)
    }
    #endif
}

#if os(iOS)
import ActivityKit

enum LiveTimer {
    @MainActor static func sync(container: ModelContainer) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let running = TimerService.current(in: container.mainContext)
        Task {
            if let running {
                let project = running.effectiveProject
                let target = project.map { $0.isActive(on: running.start) ? $0.dailyTarget : 0 } ?? 0
                // Tracked up to this session's start (the running entry adds nothing yet).
                let before = project?.tracked(in: DayMath.day(running.start), now: running.start) ?? 0
                let attributes = TimerAttributes(taskTitle: running.title, projectName: project?.name ?? "",
                                                 target: target, trackedBefore: before)
                let content = ActivityContent(state: TimerAttributes.ContentState(startedAt: running.start),
                                              staleDate: nil)
                if let existing = Activity<TimerAttributes>.activities.first {
                    if existing.attributes != attributes {
                        await existing.end(nil, dismissalPolicy: .immediate)
                        _ = try? Activity.request(attributes: attributes, content: content, pushType: nil)
                    } else {
                        await existing.update(content)
                    }
                } else {
                    _ = try? Activity.request(attributes: attributes, content: content, pushType: nil)
                }
            } else {
                for activity in Activity<TimerAttributes>.activities {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
        }
    }
}
#endif
