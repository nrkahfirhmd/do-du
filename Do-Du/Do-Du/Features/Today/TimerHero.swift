import SwiftData
import SwiftUI

struct TimerHero: View {
    let running: TimeEntry?
    /// Project a new quick session starts on when idle (nil = No project).
    @Binding var quickProject: Project?
    let projects: [Project]
    let recent: [TimeEntry]
    let now: Date
    var clockFont: Font = .ddClock
    var onPlan: () -> Void

    @Environment(\.modelContext) private var context

    private var recording: Bool { running != nil }
    #if os(macOS)
    private let heroRadius: CGFloat = 32
    #else
    private let heroRadius = DD.Radius.hero
    #endif
    private var ink: Color { recording ? .white : DD.ink }
    private var rule: Color { recording ? DD.onDarkRule : DD.track }
    private var project: Project? { running.map(\.effectiveProject) ?? quickProject }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                StatusChip(recording: recording)
                Spacer(minLength: 10)
                SwitchMenu(running: running, quickProject: $quickProject, projects: projects) {
                    ProjectChip(
                        name: project?.name ?? "No project",
                        color: project.map { chipColor($0) } ?? .clear,
                        onDark: recording)
                }
            }

            Text(running?.title ?? "No timer running")
                .font(.headline).opacity(0.8).lineLimit(1)
                .padding(.top, 28)

            Text(clock)
                .font(clockFont).tracking(-2.5).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.5)
                .padding(.top, 8)
                .contentTransition(.numericText())

            stats.padding(.top, 26)

            let window = SessionTimeline.window(now: now)
            SessionStripView(
                blocks: SessionTimeline.blocks(sessions, window: window, now: now, projectOrder: projectOrder),
                now: SessionTimeline.nowFraction(now, window: window),
                labels: SessionTimeline.labels(for: window),
                onDark: recording
            )
            .padding(.top, 22)

            #if os(macOS)
            ViewThatFits(in: .horizontal) {
                macControls(hints: true)
                macControls(hints: false)
            }
            .padding(.top, 26)
            #else
            HStack(alignment: .top, spacing: 30) {
                SwitchMenu(running: running, quickProject: $quickProject, projects: projects) {
                    sideButton("Switch", systemImage: "arrow.left.arrow.right")
                }
                RecordButton(running: recording) { toggle() }
                Button(action: onPlan) { sideButton("Plan", systemImage: "sparkles") }
                    .buttonStyle(.plain)
            }
            .padding(.top, 22)
            #endif
        }
        .foregroundStyle(ink)
        .padding(EdgeInsets(top: 18, leading: 20, bottom: 22, trailing: 20))
        .background(recording ? DD.forestFill : DD.surface, in: .dd(heroRadius))
        .animation(DD.colorChange, value: recording)
    }

    // MARK: Pieces

    #if os(macOS)
    private func macControls(hints: Bool) -> some View {
        HStack(spacing: hints ? 22 : 14) {
            RecordButton(running: recording, size: 88, showsLabel: false) { toggle() }
            VStack(alignment: .leading, spacing: 2) {
                Text(recording ? "Stop timer" : "Start timer").font(.rounded(17, .bold))
                if hints {
                    Text("Space to start or stop · ⌘⇧T anywhere").font(.system(size: 13)).opacity(0.65)
                }
            }
            .fixedSize()
            Spacer(minLength: 0)
            SwitchMenu(running: running, quickProject: $quickProject, projects: projects) {
                Text("Switch task").font(.system(size: 14, weight: .semibold)).fixedSize()
                    .padding(.horizontal, 16).frame(height: 40)
                    .background(recording ? DD.onDarkFill : DD.fill, in: Capsule())
            }
            .fixedSize()
        }
    }
    #endif

    private var stats: some View {
        let day = DayMath.day(now)
        let today = recent.tracked(in: day, now: now)
        let verdict = Stats.verdict(for: projects, on: now, now: now)
        let toEnough: (String, Bool) =
            switch verdict {
            case .restDay: ("—", false)
            case .enough: ("Done", true)
            case .notYet(let left): (left.hoursMinutes, false)
            }
        let projPct: (String, Bool) =
            project.map { p in
                let pct = p.dailyTarget > 0 ? min(1, p.tracked(in: day, now: now) / p.dailyTarget) : 1
                return ("\(Int(pct * 100))%", pct >= 1)
            } ?? ("—", false)
        return HStack(spacing: 0) {
            stat(today.hoursMinutes, "Today", good: false)
            Rectangle().fill(rule).frame(width: 1)
            stat(toEnough.0, "To enough", good: toEnough.1)
            Rectangle().fill(rule).frame(width: 1)
            stat(projPct.0, project?.name ?? "Project", good: projPct.1)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 16)
        .overlay(alignment: .top) { Rectangle().fill(rule).frame(height: 1) }
    }

    private func stat(_ value: String, _ label: String, good: Bool) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.ddStat).tracking(-0.5).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                .foregroundStyle(good ? (recording ? DD.mint : DD.forest) : ink)
            Text(label.uppercased()).font(.ddCaption).tracking(1.1).opacity(0.6).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private func sideButton(_ title: String, systemImage: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 58, height: 58)
                .background(recording ? DD.onDarkFill : DD.fill, in: Circle())
            Text(title).font(.rounded(12, .semibold)).opacity(0.6)
        }
        .padding(.top, 21)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }

    // MARK: Data

    private var clock: String {
        (running.map { now.timeIntervalSince($0.start) } ?? 0).clock
    }

    private var projectOrder: [String] {
        projects.map { String(describing: $0.persistentModelID) }
    }

    private var sessions: [(start: Date, end: Date?, projectID: String?)] {
        recent.map { e in (e.start, e.end, e.effectiveProject.map { String(describing: $0.persistentModelID) }) }
    }

    /// On the forest hero the forest swatch would vanish; use white like the strip does.
    private func chipColor(_ p: Project) -> Color {
        recording && Palette.canonical(p.colorName) == "forest" ? .white : p.color
    }

    private func toggle() {
        if running != nil {
            TimerService.stop(in: context)
        } else {
            TimerService.start(nil, project: quickProject, in: context)
        }
    }
}

struct SwitchMenu<MenuLabel: View>: View {
    let running: TimeEntry?
    @Binding var quickProject: Project?
    let projects: [Project]
    @ViewBuilder var label: MenuLabel
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<TaskItem> { !$0.isDone }, sort: \TaskItem.createdAt) private var openTasks: [TaskItem]

    var body: some View {
        Menu {
            Section(running == nil ? "Start timer for" : "Switch timer to") {
                Section("Quick session") {
                    pick("No project", selected: isQuick(nil)) { choose(project: nil) }
                    ForEach(projects) { p in
                        pick(p.name, selected: isQuick(p)) { choose(project: p) }
                    }
                }
                Section("Tasks") {
                    ForEach(openTasks.filter { $0.project?.isArchived == false }) { t in
                        pick(t.title, selected: running?.task == t) { TimerService.start(t, in: context) }
                    }
                }
            }
        } label: {
            label
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
    }

    private func isQuick(_ p: Project?) -> Bool {
        if let running { return running.task == nil && running.project == p }
        return quickProject == p
    }

    /// Running: restart as a quick session on `project`. Idle: just remember the choice.
    private func choose(project: Project?) {
        if running != nil {
            TimerService.start(nil, project: project, in: context)
        } else {
            quickProject = project
        }
    }

    private func pick(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if selected { Label(title, systemImage: "checkmark") } else { Text(title) }
        }
    }
}
