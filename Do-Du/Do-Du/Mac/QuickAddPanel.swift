//
//  QuickAddPanel.swift
//  Do-Du
//
//  Mac Quick Add: a floating glass panel 150pt from the top of the screen (⌘K in
//  the app, ⌥⌘K from anywhere). The preview strip shows exactly what Return adds:
//  the typed syntax first, then on-device Foundation Models fill the gaps after a
//  short pause. Return adds the task and shows Tasks.
//

#if os(macOS)
import AppKit
import SwiftData
import SwiftUI

@MainActor
enum QuickAddPanel {
    private static var panel: FloatingPanel?

    static func show(text: String = "") {
        let panel = panel ?? FloatingPanel()
        self.panel = panel
        // Fresh state each time it opens.
        let host = NSHostingController(rootView: QuickAddPanelView(text: text) { close() }.modelContainer(SharedStore.shared))
        host.sizingOptions = [.preferredContentSize]
        panel.contentViewController = host
        panel.layoutIfNeeded()
        if let screen = NSScreen.main?.visibleFrame {
            let size = host.view.fittingSize
            panel.setFrame(NSRect(x: screen.midX - size.width / 2, y: screen.maxY - 150 - size.height,
                                  width: size.width, height: size.height), display: true)
        }
        panel.makeKeyAndOrderFront(nil)
    }

    static func close() {
        panel?.orderOut(nil)
        panel?.contentViewController = nil
    }

    /// Spotlight-style: takes typing without activating the app, closes when it loses focus.
    private final class FloatingPanel: NSPanel {
        init() {
            super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            isFloatingPanel = true
            level = .floating
            backgroundColor = .clear
            isOpaque = false
            hasShadow = true
            hidesOnDeactivate = false
            collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        }
        override var canBecomeKey: Bool { true }
        override func resignKey() {
            super.resignKey()
            QuickAddPanel.close()
        }
    }
}

struct QuickAddPanelView: View {
    @State var text: String
    let close: () -> Void
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Project> { !$0.isArchived }, sort: \Project.createdAt) private var projects: [Project]
    @Query(sort: \Category.name) private var categories: [Category]
    @State private var refined: TaskPrefill?
    @State private var chosenProject: Project?
    @FocusState private var focused: Bool

    var body: some View {
        let draft = self.draft
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles").font(.system(size: 20, weight: .semibold)).foregroundStyle(DD.sage)
                TextField("Add a task…", text: $text)
                    .textFieldStyle(.plain)
                    .font(.rounded(22, .semibold))
                    .focused($focused)
                    .onSubmit(add)
                Text("⌘K").font(.rounded(12, .semibold)).foregroundStyle(DD.ink3)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(DD.fill, in: .rect(cornerRadius: 6))
            }
            .padding(.horizontal, 20).frame(height: 64)
            Divider()
            Text("Do-Du will add").font(.system(size: 12, weight: .semibold)).foregroundStyle(DD.ink3)
                .padding(EdgeInsets(top: 14, leading: 20, bottom: 8, trailing: 20))
            strip(draft)
                .padding(.horizontal, 14)
            HStack(spacing: 8) {
                Text("Read on this Mac. Use ~ for an estimate and # for a category.")
                    .font(.system(size: 12)).foregroundStyle(DD.ink3)
                Spacer(minLength: 8)
                Button("Cancel", action: close)
                    .buttonStyle(CapsuleButton(fill: DD.sheetButton, ink: DD.ink))
                    .keyboardShortcut(.cancelAction)
                Button("Add Task  ↩", action: add)
                    .buttonStyle(CapsuleButton(fill: canAdd(draft) ? DD.forestFill : DD.disabled, ink: .white))
                    .disabled(!canAdd(draft))
            }
            .padding(EdgeInsets(top: 16, leading: 20, bottom: 18, trailing: 20))
        }
        .frame(width: 640)
        .background(.regularMaterial, in: .rect(cornerRadius: 22))
        .clipShape(.rect(cornerRadius: 22))
        .onAppear { focused = true }
        .onExitCommand(perform: close)
        // Foundation Models fill what the syntax didn't, once typing pauses.
        .task(id: text) {
            refined = nil
            guard QuickAddParser.isAvailable, !text.isBlank else { return }
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            refined = try? await QuickAddParser.parse(text, projects: projects, categories: categories)
        }
    }

    // MARK: Draft

    private var draft: TaskPrefill {
        let weekday = Calendar.current.component(.weekday, from: DayMath.logicalDate(.now))
        let s = QuickAddSyntax.read(text, projects: projects.map(\.name), categories: categories.map(\.name), weekday: weekday)
        let today = DayMath.logicalDate(.now)
        // Typed syntax wins; the model only fills gaps (and tidies the title).
        return TaskPrefill(
            title: refined?.title.isBlank == false ? refined!.title : s.title,
            project: chosenProject ?? projects.first { $0.name == s.projectName } ?? refined?.project,
            category: categories.first { $0.name == s.categoryName } ?? refined?.category,
            dueDate: s.dueInDays.flatMap { Calendar.current.date(byAdding: .day, value: $0, to: today) } ?? refined?.dueDate,
            estimateMinutes: s.estimateMinutes ?? refined?.estimateMinutes)
    }

    private func canAdd(_ d: TaskPrefill) -> Bool { !d.title.isBlank && d.project != nil }

    private func add() {
        let d = draft
        guard canAdd(d) else { return }
        let task = TaskItem(title: d.title, project: d.project)
        task.category = d.category
        task.dueDate = d.dueDate
        task.estimateMinutes = d.estimateMinutes
        context.insert(task)
        try? context.save()
        close()
        NSWorkspace.shared.open(URL(string: "dodu://tasks")!)
    }

    // MARK: Strip

    private func strip(_ d: TaskPrefill) -> some View {
        let today = DayMath.logicalDate(.now)
        let dueText: String? = d.dueDate.map { date in
            let days = Calendar.current.dateComponents([.day], from: today, to: date).day ?? 0
            return days == 0 ? "Today" : days == 1 ? "Tomorrow" : date.formatted(.dateTime.weekday(.abbreviated).day())
        }
        return HStack(spacing: 0) {
            // 1.7fr / 1fr ×4 of the 612pt strip.
            cell("Task", d.title.isBlank ? nil : d.title).frame(width: 182)
            Divider()
            projectCell(d.project)
            Divider()
            cell("Category", d.category?.name, swatch: d.category?.color)
            Divider()
            cell("Due", dueText, ink: dueText == "Today" ? DD.danger : DD.ink)
            Divider()
            cell("Estimate", d.estimateMinutes.map(compactHours))
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(DD.surface, in: .dd(16))
    }

    private func cell(_ label: String, _ value: String?, swatch: Color? = nil, ink: Color = DD.ink) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased()).font(.rounded(11, .bold)).tracking(1.1).foregroundStyle(DD.ink3)
            HStack(spacing: 6) {
                if let swatch, value != nil {
                    RoundedRectangle(cornerRadius: 3, style: .continuous).fill(swatch).frame(width: 9, height: 9)
                }
                Text(value ?? "None").font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(value == nil ? DD.ink3 : ink).lineLimit(1)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Unknown project: pick one here (tasks always belong to a project).
    private func projectCell(_ project: Project?) -> some View {
        Menu {
            ForEach(projects) { p in Button(p.name) { chosenProject = p } }
        } label: {
            cell("Project", project?.name ?? (text.isBlank ? nil : "Choose…"), swatch: project?.color,
                 ink: project == nil ? DD.danger : DD.ink)
        }
        .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden)
    }
}

/// 30pt capsule button for Mac sheet and panel footers.
struct CapsuleButton: ButtonStyle {
    let fill: Color
    let ink: Color
    var height: CGFloat = 30

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold)).foregroundStyle(ink)
            .padding(.horizontal, height == 30 ? 14 : 12).frame(height: height)
            .background(fill, in: Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
            .contentShape(Capsule())
    }
}
#endif
