//
//  TimerActivity.swift
//  Do-Du
//
//  Shared Live Activity definition: compiled into the app (to start/end
//  activities) and into the widget extension (to render them).
//

#if os(iOS)
import ActivityKit
import SwiftUI
import WidgetKit

/// Plain data: opted out of the module's MainActor default so ActivityKit
/// can use it from concurrent contexts.
nonisolated struct TimerAttributes: ActivityAttributes, Equatable {
    struct ContentState: Codable, Hashable {
        /// Timer start; views render a live `Text(_:style:.timer)` from it.
        var startedAt: Date
    }

    var taskTitle: String
    var projectName: String
}

struct TimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerAttributes.self) { context in
            HStack(spacing: 10) {
                Image(systemName: "timer").foregroundStyle(.red)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.taskTitle).font(.headline).lineLimit(1)
                    if !context.attributes.projectName.isEmpty {
                        Text(context.attributes.projectName)
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer()
                Text(context.state.startedAt, style: .timer)
                    .font(.title3).monospacedDigit()
            }
            .padding()
            .activityBackgroundTint(Color(.systemBackground))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.taskTitle, systemImage: "timer")
                        .font(.headline).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.startedAt, style: .timer)
                        .font(.title3).monospacedDigit()
                }
            } compactLeading: {
                Image(systemName: "timer").foregroundStyle(.red)
            } compactTrailing: {
                Text(context.state.startedAt, style: .timer).monospacedDigit()
            } minimal: {
                Image(systemName: "timer").foregroundStyle(.red)
            }
        }
    }
}
#else
import SwiftUI
import WidgetKit

/// macOS has no ActivityKit (`Widget` itself lives in SwiftUI here):
/// contributes no Live Activity to the bundle.
struct TimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        EmptyWidgetConfiguration()
    }
}
#endif
