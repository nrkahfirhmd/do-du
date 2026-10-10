//
//  TodayWidget.swift
//  Do-Du
//
//  Today progress widget: verdict banner + per-project tracked/target.
//  Reads the shared App Group store; never writes.
//

import SwiftData
import SwiftUI
import WidgetKit

struct TodayWidgetEntry: TimelineEntry {
    let date: Date
    let title: String
    let subtitle: String
    let rows: [Row]
    let needsSetup: Bool

    struct Row: Identifiable {
        let name: String
        let tracked: TimeInterval
        let target: TimeInterval
        let colorName: String
        var id: String { name }
    }
}

struct TodayWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayWidgetEntry {
        TodayWidgetEntry(date: .now, title: "Not yet", subtitle: "1h 30m left across your projects.",
                         rows: [TodayWidgetEntry.Row(name: "Do-Du", tracked: 3600, target: 10800, colorName: "forest")],
                         needsSetup: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayWidgetEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayWidgetEntry>) -> Void) {
        // Timer start/stop forces a reload via WidgetCenter; this is the backstop.
        completion(Timeline(entries: [loadEntry()], policy: .after(.now.addingTimeInterval(15 * 60))))
    }

    private func loadEntry(now: Date = .now) -> TodayWidgetEntry {
        guard let url = SharedStore.storeURL(groupURL: SharedStore.groupURL),
              let container = try? ModelContainer(
                  for: Schema(allModels),
                  configurations: [ModelConfiguration(schema: Schema(allModels), url: url,
                                                      cloudKitDatabase: .none)]) else {
            return TodayWidgetEntry(date: now, title: "Open Do-Du", subtitle: "Sign in to sync.",
                                    rows: [], needsSetup: true)
        }
        let context = ModelContext(container)
        let projects = (try? context.fetch(FetchDescriptor<Project>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        let day = DayMath.day(now)
        let active = projects.filter { $0.isActive(on: now) }
        let rows = active.map {
            TodayWidgetEntry.Row(name: $0.name, tracked: $0.tracked(in: day, now: now),
                                 target: $0.dailyTarget, colorName: $0.colorName)
        }
        let verdict = Stats.verdict(for: projects, on: now, now: now)
        switch verdict {
        case .enough:
            return TodayWidgetEntry(date: now, title: "Enough ✓",
                                    subtitle: "Every project hit its target.", rows: rows, needsSetup: false)
        case .restDay:
            return TodayWidgetEntry(date: now, title: "Rest day",
                                    subtitle: "No projects scheduled today.", rows: rows, needsSetup: false)
        case .notYet(let remaining):
            return TodayWidgetEntry(date: now, title: "Not yet",
                                    subtitle: "\(remaining.hoursMinutes) left across your projects.",
                                    rows: rows, needsSetup: false)
        }
    }
}

struct TodayWidgetView: View {
    let entry: TodayWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: entry.needsSetup ? "icloud.slash" : "sun.max")
                    .foregroundStyle(.orange)
                Text(entry.title).font(.headline).lineLimit(1)
            }
            Text(entry.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            ForEach(entry.rows.prefix(3)) { row in
                HStack(spacing: 6) {
                    Circle().fill(Palette.color(row.colorName)).frame(width: 8, height: 8)
                    Text(row.name).font(.caption).lineLimit(1)
                    Spacer()
                    Text("\(row.tracked.hoursMinutes)/\(row.target.hoursMinutes)")
                        .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                }
                ProgressView(value: row.target > 0 ? min(1, row.tracked / row.target) : 1)
                    .tint(Palette.color(row.colorName))
            }
        }
    }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.kv.Do-Du.today", provider: TodayWidgetProvider()) { entry in
            TodayWidgetView(entry: entry)
        }
        .configurationDisplayName("Today")
        .description("Project targets and whether you've done enough.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
