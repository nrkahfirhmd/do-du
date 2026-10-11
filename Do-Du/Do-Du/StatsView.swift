//
//  StatsView.swift
//  Do-Du
//

import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    enum Period: String, CaseIterable, Identifiable {
        case day = "Day", week = "Week", month = "Month"
        var id: Self { self }
        var component: Calendar.Component {
            switch self { case .day: .day; case .week: .weekOfYear; case .month: .month }
        }
    }

    @Query(sort: \Project.createdAt) private var projects: [Project]
    @Query private var entries: [TimeEntry]
    @State private var period = Period.week
    @State private var anchor = Date.now
    @State private var selectedDay: Date?

    private let cal = Calendar.current

    var body: some View {
        let now = Date.now
        let range = DayMath.period(period.component, for: anchor)
        let days = DayMath.logicalDates(in: range)
        let byProject = totals(in: range, now: now) { $0.effectiveProject?.name ?? "No project" }
        let byCategory = totals(in: range, now: now) { $0.task?.category?.name ?? "Uncategorized" }
        let pastDays = days.map { DayMath.dayStarting($0).start }.filter { $0 <= now }
        let verdicts = pastDays.map { Stats.verdict(for: projects, on: $0, now: now) }
        let workDays = verdicts.filter { $0 != .restDay }.count
        let enoughDays = verdicts.filter { $0 == .enough }.count

        List {
            Section {
                Picker("Period", selection: $period) {
                    ForEach(Period.allCases) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                HStack {
                    Button("Previous", systemImage: "chevron.left") { shift(-1) }.labelStyle(.iconOnly)
                        .frame(width: 44, height: 44)
                    Spacer()
                    Text(title(range)).font(.headline).foregroundStyle(DD.ink)
                    Spacer()
                    Button("Next", systemImage: "chevron.right") { shift(1) }
                        .labelStyle(.iconOnly)
                        .frame(width: 44, height: 44)
                        .disabled(range.end > now)
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(DD.sage)
                .buttonStyle(.borderless)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))

            Section {
                HStack(spacing: 10) {
                    StatTile(label: "Total tracked", value: byProject.reduce(0) { $0 + $1.seconds }.hoursMinutes, tone: .forest)
                    StatTile(label: "Enough days", value: workDays == 0 ? "—" : "\(enoughDays) of \(workDays)", tone: .mint)
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            Section("By project") {
                if byProject.isEmpty { Text("No time tracked.").foregroundStyle(DD.ink3) }
                else { TotalsChart(rows: byProject, color: projectColor) }
            }
            .listRowBackground(DD.surface)

            Section("By category") {
                if byCategory.isEmpty { Text("No time tracked.").foregroundStyle(DD.ink3) }
                else { TotalsChart(rows: byCategory, color: categoryColor) }
            }
            .listRowBackground(DD.surface)

            if period != .day, !byProject.isEmpty {
                Section("Daily trend") { trendChart(days: days, now: now) }
                    .listRowBackground(DD.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(DD.page)
        .animation(DD.fillChange, value: range)
        .navigationTitle("Stats")
    }

    // MARK: Charts

    private func trendChart(days: [Date], now: Date) -> some View {
        let names = projects.map(\.name)
        let rows = days.flatMap { day -> [(day: Date, project: String, hours: Double)] in
            let interval = DayMath.dayStarting(day)
            return projects.compactMap { p in
                let h = p.tracked(in: interval, now: now) / 3600
                return h > 0 ? (day, p.name, h) : nil
            }
        }
        return Chart {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                BarMark(x: .value("Day", r.day, unit: .day), y: .value("Hours", r.hours))
                    .foregroundStyle(by: .value("Project", r.project))
                    .cornerRadius(5)
            }
            if let selectedDay {
                RuleMark(x: .value("Day", selectedDay, unit: .day))
                    .foregroundStyle(.secondary.opacity(0.3))
                    .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                        let interval = DayMath.dayStarting(selectedDay)
                        VStack(alignment: .leading) {
                            Text(selectedDay.formatted(.dateTime.weekday().day().month())).font(.caption.bold())
                            ForEach(projects.filter { $0.tracked(in: interval, now: now) > 0 }) { p in
                                Text("\(p.name): \(p.tracked(in: interval, now: now).hoursMinutes)").font(.caption)
                            }
                        }
                        .padding(6)
                        .background(.background, in: RoundedRectangle(cornerRadius: 6))
                        .shadow(radius: 2)
                    }
            }
        }
        .chartForegroundStyleScale(domain: names, range: projects.map(\.color))
        .chartXSelection(value: $selectedDay)
        .chartYAxisLabel("Hours")
        .chartLegend(.visible)
        .frame(height: 220)
        .padding(.vertical, 8)
    }

    // MARK: Data

    private func totals(in range: DateInterval, now: Date,
                        by key: (TimeEntry) -> String?) -> [TotalsChart.Row] {
        Dictionary(grouping: entries) { key($0) ?? "" }
            .filter { !$0.key.isEmpty }
            .map { TotalsChart.Row(name: $0.key, seconds: $0.value.tracked(in: range, now: now)) }
            .filter { $0.seconds > 0 }
            .sorted { $0.seconds > $1.seconds }
    }

    private func projectColor(_ name: String) -> Color { projects.first { $0.name == name }?.color ?? DD.disabled }

    private func categoryColor(_ name: String) -> Color {
        entries.lazy.compactMap { $0.task?.category }.first { $0.name == name }?.color ?? DD.disabled
    }

    private func shift(_ n: Int) {
        anchor = cal.date(byAdding: period.component, value: n, to: anchor)!
        selectedDay = nil
    }

    private func title(_ range: DateInterval) -> String {
        switch period {
        case .day: range.start.formatted(.dateTime.weekday(.wide).day().month())
        case .week: "\(range.start.formatted(.dateTime.day().month())) – \(range.end.addingTimeInterval(-1).formatted(.dateTime.day().month()))"
        case .month: range.start.formatted(.dateTime.month(.wide).year())
        }
    }
}

/// Horizontal bars with the value labeled at the end (doubles as the table view).
struct TotalsChart: View {
    struct Row: Identifiable {
        let name: String
        let seconds: TimeInterval
        var id: String { name }
    }

    let rows: [Row]
    let color: (String) -> Color

    var body: some View {
        Chart(rows) { r in
            BarMark(x: .value("Hours", r.seconds / 3600), y: .value("Name", r.name), height: .fixed(16))
                .foregroundStyle(color(r.name))
                .cornerRadius(8)
                .annotation(position: .trailing) {
                    Text(r.seconds.hoursMinutes).font(.rounded(13, .semibold)).foregroundStyle(DD.ink3).monospacedDigit()
                }
        }
        .chartXAxis(.hidden)
        .chartYAxis { AxisMarks { AxisValueLabel().font(.subheadline).foregroundStyle(DD.ink) } }
        .frame(height: CGFloat(rows.count) * 36 + 8)
        .padding(.vertical, 4)
    }
}
