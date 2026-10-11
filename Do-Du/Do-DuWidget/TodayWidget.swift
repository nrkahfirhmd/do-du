import SwiftData
import SwiftUI
import WidgetKit

// MARK: - Data

struct DoDuEntry: TimelineEntry {
    struct Row: Identifiable {
        let name: String
        let tracked: TimeInterval
        let target: TimeInterval
        let colorName: String
        var id: String { name }
        var met: Bool { tracked >= target }
    }
    struct Running {
        let title: String
        let project: String?
        let colorName: String?
        let start: Date
    }

    let date: Date
    let verdict: Verdict
    let progress: Double
    let rows: [Row]
    let running: Running?
    let needsSetup: Bool

    static let toggleURL = URL(string: "dodu://timer/toggle")!
    static let todayURL = URL(string: "dodu://today")!

    static let preview = DoDuEntry(
        date: .now, verdict: .notYet(remaining: 8160), progress: 0.45,
        rows: [Row(name: "Do-Du", tracked: 6540, target: 10800, colorName: "forest"),
               Row(name: "Client X", tracked: 3600, target: 7200, colorName: "moss")],
        running: Running(title: "Build Today view", project: "Do-Du", colorName: "forest", start: .now.addingTimeInterval(-552)),
        needsSetup: false)
}

struct DoDuProvider: TimelineProvider {
    func placeholder(in context: Context) -> DoDuEntry { .preview }

    func getSnapshot(in context: Context, completion: @escaping (DoDuEntry) -> Void) {
        completion(context.isPreview ? .preview : load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DoDuEntry>) -> Void) {
        let entry = load()
        // Timer changes reload timelines from the app; this refresh keeps totals fresh while running.
        let next = entry.running == nil ? 15.0 : 5.0
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(next * 60))))
    }

    private func load(now: Date = .now) -> DoDuEntry {
        // Never create the store: the app opens it first, and onboarding treats a store file as an existing user.
        guard let url = SharedStore.storeURL(groupURL: SharedStore.groupURL),
              FileManager.default.fileExists(atPath: url.path),
              let container = try? ModelContainer(
                for: Schema(allModels),
                configurations: [ModelConfiguration(schema: Schema(allModels), url: url, cloudKitDatabase: .none)]) else {
            return DoDuEntry(date: now, verdict: .restDay, progress: 0, rows: [], running: nil, needsSetup: true)
        }
        let context = ModelContext(container)
        let projects = (try? context.fetch(FetchDescriptor<Project>(
            predicate: #Predicate { !$0.isArchived }, sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        let day = DayMath.day(now)
        let active = projects.filter { $0.isActive(on: now) }
        let rows = active.map {
            DoDuEntry.Row(name: $0.name, tracked: $0.tracked(in: day, now: now), target: $0.dailyTarget, colorName: $0.colorName)
        }
        let total = rows.reduce(0) { $0 + $1.target }
        let covered = rows.reduce(0) { $0 + min($1.target, $1.tracked) }
        let runningEntry = (try? context.fetch(FetchDescriptor<TimeEntry>(predicate: #Predicate { $0.end == nil })))?
            .max { $0.start < $1.start }
        let running = runningEntry.map {
            DoDuEntry.Running(title: $0.title, project: $0.effectiveProject?.name,
                              colorName: $0.effectiveProject?.colorName, start: $0.start)
        }
        return DoDuEntry(date: now, verdict: Stats.verdict(for: projects, on: now, now: now),
                         progress: total > 0 ? covered / total : 0, rows: rows, running: running, needsSetup: false)
    }
}

// MARK: - Shared bits

private extension Verdict {
    var kicker: String {
        switch self { case .notYet: "NOT YET"; case .enough: "ENOUGH"; case .restDay: "REST DAY" }
    }
    var bigValue: String {
        switch self { case .notYet(let r): r.hoursMinutes; case .enough: "Done ✓"; case .restDay: "Off" }
    }
    var caption: String {
        switch self {
        case .notYet: "to call it a day"
        case .enough: "Stopping is allowed."
        case .restDay: "Nothing is scheduled today."
        }
    }
    /// Widgets ignore AttributedString backgrounds, so the key value is sage text instead of a mint tag.
    var sentence: Text {
        func highlighted(_ before: String, _ key: String, _ after: String) -> Text {
            Text("\(before)\(Text(key).foregroundStyle(DD.sage))\(after)")
        }
        return switch self {
        case .notYet(let r): highlighted("You need ", r.hoursMinutes, " more to call it a day.")
        case .enough: highlighted("You’ve done ", "enough", ". Stopping is allowed.")
        case .restDay: highlighted("Rest day. ", "Nothing", " is scheduled.")
        }
    }
}

private struct ToggleLink: View {
    let running: Bool
    var size: CGFloat = 40

    var body: some View {
        Link(destination: DoDuEntry.toggleURL) {
            Group {
                if running {
                    RoundedRectangle(cornerRadius: size * 0.08, style: .continuous).fill(DD.onMint)
                        .frame(width: size * 0.3, height: size * 0.3)
                } else {
                    Image(systemName: "play.fill").font(.system(size: size * 0.36, weight: .bold)).foregroundStyle(DD.mint)
                        .offset(x: size * 0.03)
                }
            }
            .frame(width: size, height: size)
            .background(running ? DD.mint : DD.forestFill, in: Circle())
        }
        .accessibilityLabel(running ? "Stop timer" : "Start timer")
    }
}

private struct ProjectBar: View {
    let row: DoDuEntry.Row
    var height: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(row.name).font(.caption.weight(.semibold)).lineLimit(1)
                Spacer()
                Text("\(row.tracked.hoursMinutes) / \(row.target.hoursMinutes)").font(.rounded(11, .semibold)).monospacedDigit().opacity(0.7)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(DD.track)
                    Capsule().fill(row.met ? DD.mint : Palette.color(row.colorName))
                        .frame(width: geo.size.width * min(1, row.target > 0 ? row.tracked / row.target : 1))
                }
            }
            .frame(height: height)
        }
    }
}

// MARK: - Today widget (verdict)

struct TodayWidgetView: View {
    let entry: DoDuEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall: small
        case .systemMedium: medium
        case .systemLarge: large
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        default: inline
        }
    }

    private var enough: Bool { entry.verdict == .enough }

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text(entry.verdict.kicker).font(.rounded(11, .heavy)).tracking(1.1).opacity(0.65)
                Spacer()
                ProgressRing(value: enough ? 1 : entry.progress, size: 30, thickness: 4,
                             color: enough ? DD.onMint : DD.forest, track: enough ? DD.onMint.opacity(0.15) : DD.track)
            }
            Spacer(minLength: 0)
            Text(entry.verdict.bigValue).font(.rounded(40)).tracking(-1).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.5)
            Text(entry.verdict.caption).font(.footnote).opacity(0.7).lineLimit(2)
        }
        .foregroundStyle(enough ? DD.onMint : DD.forest)
        .containerBackground(for: .widget) { enough ? DD.mint : DD.page }
        .widgetURL(DoDuEntry.todayURL)
    }

    private var medium: some View {
        HStack(spacing: 14) {
            TimerCard(running: entry.running)
                .frame(width: 150)
            VStack(alignment: .leading, spacing: 8) {
                entry.verdict.sentence.font(.rounded(17, .heavy)).foregroundStyle(DD.forest)
                    .lineLimit(3).minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                ForEach(entry.rows.prefix(2)) { ProjectBar(row: $0) }
            }
            .foregroundStyle(DD.ink)
        }
        .containerBackground(DD.page, for: .widget)
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today").font(.ddTitle3).foregroundStyle(DD.forest)
                Spacer()
                Text(entry.date.formatted(.dateTime.weekday(.wide).day().month())).font(.footnote).foregroundStyle(DD.ink3)
            }
            entry.verdict.sentence.font(.rounded(26, .heavy)).foregroundStyle(DD.forest).lineLimit(3)
            dayBar
            HStack(spacing: 10) {
                ForEach(entry.rows.prefix(2)) { row in
                    HStack(spacing: 10) {
                        ProgressRing(value: row.target > 0 ? row.tracked / row.target : 1, size: 44, thickness: 6,
                                     color: row.met ? DD.onMint : Palette.color(row.colorName),
                                     track: row.met ? DD.onMint.opacity(0.15) : DD.track)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(row.name).font(.rounded(14, .bold)).lineLimit(1)
                            Text(row.met ? "DONE ✓" : "\(row.tracked.hoursMinutes) of \(row.target.hoursMinutes)")
                                .font(.rounded(12, .semibold)).monospacedDigit().opacity(0.75)
                        }
                    }
                    .foregroundStyle(row.met ? DD.onMint : DD.ink)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(row.met ? DD.mint : DD.surface, in: .dd(20))
                }
            }
            Spacer(minLength: 0)
            timerRow
        }
        .containerBackground(DD.page, for: .widget)
    }

    private var dayBar: some View {
        GeometryReader { geo in
            let total = max(1, entry.rows.reduce(0) { $0 + $1.target })
            HStack(spacing: 2) {
                ForEach(entry.rows) { row in
                    let w = geo.size.width * row.target / total
                    ZStack(alignment: .leading) {
                        Rectangle().fill(DD.track)
                        Rectangle().fill(row.met ? DD.mint : Palette.color(row.colorName))
                            .frame(width: w * min(1, row.tracked / max(1, row.target)))
                    }
                    .frame(width: max(0, w - 2))
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: 14)
    }

    private var timerRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.running?.title ?? "No timer running").font(.subheadline.weight(.semibold)).lineLimit(1).opacity(0.8)
                if let r = entry.running {
                    Text(r.start, style: .timer).font(.rounded(22)).monospacedDigit()
                } else {
                    Text("0:00:00").font(.rounded(22)).monospacedDigit()
                }
            }
            Spacer()
            ToggleLink(running: entry.running != nil, size: 44)
        }
        .foregroundStyle(entry.running != nil ? Color.white : DD.ink)
        .padding(12)
        .background(entry.running != nil ? DD.forestFill : DD.surface, in: .dd(DD.Radius.card))
    }

    private var circular: some View {
        Gauge(value: enough ? 1 : entry.progress) {
            Image(systemName: "stopwatch")
        } currentValueLabel: {
            switch entry.verdict {
            case .notYet(let r): Text(r.hoursMinutes.replacingOccurrences(of: " ", with: ""))
            case .enough: Text("✓")
            case .restDay: Text("Off")
            }
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .containerBackground(.clear, for: .widget)
        .widgetURL(DoDuEntry.todayURL)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.verdict == .enough ? "Enough" : entry.verdict == .restDay ? "Rest day" : "Not yet").font(.headline)
            Text(rectangularLine).font(.caption).lineLimit(1)
            ProgressView(value: enough ? 1 : entry.progress)
        }
        .containerBackground(.clear, for: .widget)
        .widgetURL(DoDuEntry.todayURL)
    }

    private var rectangularLine: String {
        switch entry.verdict {
        case .notYet(let r): "\(r.hoursMinutes) to call it a day"
        case .enough: "Stopping is allowed."
        case .restDay: "Nothing is scheduled today."
        }
    }

    private var inline: some View {
        Group {
            switch entry.verdict {
            case .notYet(let r): Text("Do-Du · \(r.hoursMinutes) to go")
            case .enough: Text("Do-Du · enough ✓")
            case .restDay: Text("Do-Du · rest day")
            }
        }
        .containerBackground(.clear, for: .widget)
    }
}

private struct TimerCard: View {
    let running: DoDuEntry.Running?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(running != nil ? "RECORDING" : "READY").font(.rounded(10, .heavy)).tracking(1)
                .foregroundStyle(running != nil ? DD.mint : DD.ink3)
            Spacer(minLength: 0)
            if let running {
                Text(running.start, style: .timer).font(.rounded(28)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
            } else {
                Text("0:00:00").font(.rounded(28)).monospacedDigit()
            }
            HStack(alignment: .bottom) {
                Text(running?.title ?? "Tap to start").font(.caption.weight(.semibold)).lineLimit(2).opacity(0.8)
                Spacer(minLength: 4)
                ToggleLink(running: running != nil, size: 32)
            }
        }
        .foregroundStyle(running != nil ? Color.white : DD.ink)
        .padding(12)
        .frame(maxHeight: .infinity)
        .background(running != nil ? DD.forestFill : DD.surface, in: .dd(20))
    }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.kv.Do-Du.today", provider: DoDuProvider()) { TodayWidgetView(entry: $0) }
            .configurationDisplayName("Today")
            .description("Whether you've done enough, with project targets.")
            .supportedFamilies(families)
    }

    private var families: [WidgetFamily] {
        #if os(iOS)
        [.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline]
        #else
        [.systemSmall, .systemMedium, .systemLarge]
        #endif
    }
}

// MARK: - Timer widget

struct TimerWidgetView: View {
    let entry: DoDuEntry

    var body: some View {
        let running = entry.running
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle().fill(running != nil ? DD.mint : DD.ink3.opacity(0.6)).frame(width: 7, height: 7)
                Text(running != nil ? "RECORDING" : "READY").font(.rounded(11, .heavy)).tracking(1.1)
                    .foregroundStyle(running != nil ? DD.mint : DD.ink3)
            }
            Text(running?.title ?? "No timer running").font(.subheadline.weight(.semibold)).lineLimit(1).opacity(0.85)
                .padding(.top, 6)
            Group {
                if let running {
                    Text(running.start, style: .timer)
                } else {
                    Text("0:00:00")
                }
            }
            .font(.rounded(34)).tracking(-1).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
            Spacer(minLength: 0)
            HStack {
                if let project = running?.project {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(running?.colorName.map(Palette.color) ?? .clear).frame(width: 10, height: 10)
                    Text(project).font(.caption.weight(.semibold)).lineLimit(1)
                } else {
                    Text(running == nil ? "Tap to start" : "No project").font(.caption.weight(.semibold)).opacity(0.7)
                }
                Spacer()
                ToggleLink(running: running != nil)
            }
        }
        .foregroundStyle(running != nil ? Color.white : DD.ink)
        .containerBackground(for: .widget) { running != nil ? DD.forestFill : DD.page }
        // Small widgets only take one tap target: the whole widget toggles via the app.
        .widgetURL(DoDuEntry.toggleURL)
    }
}

struct TimerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.kv.Do-Du.timer", provider: DoDuProvider()) { TimerWidgetView(entry: $0) }
            .configurationDisplayName("Timer")
            .description("The running timer, with start and stop.")
            .supportedFamilies([.systemSmall])
    }
}
