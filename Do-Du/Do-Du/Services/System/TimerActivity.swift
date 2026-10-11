#if os(iOS)
import ActivityKit
import SwiftUI
import WidgetKit

/// Plain data: opted out of the module's MainActor default so ActivityKit can use it from concurrent contexts.
nonisolated struct TimerAttributes: ActivityAttributes, Equatable {
    struct ContentState: Codable, Hashable {
        var startedAt: Date
    }

    var taskTitle: String
    var projectName: String
    /// Project target and time tracked before this session, so progress runs live from `startedAt`.
    var target: TimeInterval = 0
    var trackedBefore: TimeInterval = 0
}

/// Stop opens the app via `dodu://timer/toggle`, like the widgets.
struct TimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerAttributes.self) { context in
            LiveBanner(attributes: context.attributes, startedAt: context.state.startedAt)
                .activityBackgroundTint(Color(hex: 0x1A312C))
                .activitySystemActionForegroundColor(DD.mint)
        } dynamicIsland: { context in
            let a = context.attributes, start = context.state.startedAt
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous).fill(DD.mint).frame(width: 9, height: 9)
                        Text(a.projectName.isEmpty ? "No project" : a.projectName).font(.rounded(13, .bold)).lineLimit(1)
                    }
                    .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    LeftText(attributes: a, startedAt: start).padding(.trailing, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(a.taskTitle).font(.subheadline.weight(.semibold)).opacity(0.75).lineLimit(1)
                            Text(start, style: .timer).font(.rounded(44, .heavy)).monospacedDigit()
                                .foregroundStyle(DD.mint)
                        }
                        Spacer(minLength: 0)
                        StopLink(size: 50)
                    }
                    .padding(.horizontal, 6)
                }
            } compactLeading: {
                StopGlyph(size: 16, glyph: 6)
            } compactTrailing: {
                Text(start, style: .timer).font(.rounded(15, .bold)).monospacedDigit()
                    .foregroundStyle(DD.mint).frame(maxWidth: 52)
            } minimal: {
                if let range = a.progressRange(startedAt: start) {
                    ProgressView(timerInterval: range, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                        .progressViewStyle(.circular).tint(DD.mint)
                } else {
                    StopGlyph(size: 16, glyph: 6)
                }
            }
            .widgetURL(URL(string: "dodu://today"))
            .keylineTint(DD.mint)
        }
    }
}

extension TimerAttributes {
    func progressRange(startedAt: Date) -> ClosedRange<Date>? {
        guard target > 0 else { return nil }
        let zero = startedAt.addingTimeInterval(-trackedBefore)
        return zero...zero.addingTimeInterval(target)
    }
}

private struct LiveBanner: View {
    let attributes: TimerAttributes
    let startedAt: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Circle().fill(DD.onMint).frame(width: 6, height: 6)
                    Text("RECORDING").font(.rounded(10, .heavy)).tracking(1.2)
                }
                .foregroundStyle(DD.onMint)
                .padding(.horizontal, 10).frame(height: 24)
                .background(DD.mint, in: Capsule())
                Text(attributes.projectName.isEmpty ? "No project" : attributes.projectName)
                    .font(.rounded(13, .bold)).opacity(0.8).lineLimit(1)
                Spacer(minLength: 0)
                LeftText(attributes: attributes, startedAt: startedAt)
            }
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(attributes.taskTitle).font(.subheadline.weight(.semibold)).opacity(0.8).lineLimit(1)
                    Text(startedAt, style: .timer).font(.rounded(48, .heavy)).monospacedDigit()
                }
                Spacer(minLength: 0)
                StopLink(size: 52)
            }
            .padding(.top, 10)
            if let range = attributes.progressRange(startedAt: startedAt) {
                ProgressView(timerInterval: range, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                    .progressViewStyle(.linear).tint(DD.mint)
                    .padding(.top, 12)
            }
        }
        .foregroundStyle(.white)
        .padding(EdgeInsets(top: 16, leading: 18, bottom: 14, trailing: 16))
    }
}

private struct LeftText: View {
    let attributes: TimerAttributes
    let startedAt: Date

    var body: some View {
        Group {
            if attributes.target > 0 {
                let left = attributes.target - attributes.trackedBefore
                if left > 0 {
                    Text("\(Text(timerInterval: startedAt...startedAt.addingTimeInterval(left), countsDown: true)) to enough")
                        .monospacedDigit()
                } else {
                    Text("Enough ✓")
                }
            }
        }
        .font(.rounded(12, .bold)).opacity(0.6).lineLimit(1)
    }
}

private struct StopGlyph: View {
    let size: CGFloat
    let glyph: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: glyph / 4, style: .continuous).fill(DD.onMint)
            .frame(width: glyph, height: glyph)
            .frame(width: size, height: size)
            .background(DD.mint, in: Circle())
    }
}

private struct StopLink: View {
    let size: CGFloat

    var body: some View {
        Link(destination: URL(string: "dodu://timer/toggle")!) {
            StopGlyph(size: size, glyph: size * 0.31)
        }
        .accessibilityLabel("Stop timer")
    }
}
#else
import SwiftUI
import WidgetKit

/// macOS has no ActivityKit (`Widget` itself lives in SwiftUI here): contributes no Live Activity to the bundle.
struct TimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        EmptyWidgetConfiguration()
    }
}
#endif
