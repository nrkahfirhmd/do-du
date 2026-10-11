import SwiftData
import SwiftUI

struct ProjectsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Project.createdAt) private var projects: [Project]
    @State private var editing: Project?
    @State private var creating = false
    @State private var deleting: Project?
    @State private var showArchived = false

    var body: some View {
        content
            .background(DD.page)
            .navigationTitle("Projects")
            .sheet(isPresented: $creating) { ProjectEditor(project: nil) }
            .sheet(item: $editing) { ProjectEditor(project: $0) }
            .confirmationDialog(
                "Delete \(deleting?.name ?? "project")?",
                isPresented: .init(
                    get: { deleting != nil }, set: { if !$0 { deleting = nil } })
            ) {
                Button("Delete Project, Tasks and Time", role: .destructive) {
                    if let deleting { context.delete(deleting) }
                }
            } message: {
                Text("All tasks and tracked time in this project are removed. Archive instead to keep history.")
            }
    }

    #if os(macOS)
    private var content: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 14) {
                ForEach(projects.sorted { !$0.isArchived && $1.isArchived }) { p in
                    ProjectColorTile(project: p, height: 200)
                        .opacity(p.isArchived ? 0.5 : 1)
                        .onTapGesture { editing = p }
                        .contextMenu { menu(p) }
                }
                Button {
                    creating = true
                } label: {
                    Text("+ New project  ⌘N")
                        .font(.rounded(17, .bold)).foregroundStyle(DD.sage)
                        .padding(20)
                        .frame(maxWidth: .infinity, minHeight: 200, alignment: .bottomLeading)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .strokeBorder(DD.disabled, style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                        )
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("n")
            }
            .padding(EdgeInsets(top: 20, leading: 28, bottom: 28, trailing: 28))
        }
    }
    #else
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader("Active")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                    ForEach(projects.filter { !$0.isArchived }) { p in
                        ProjectColorTile(project: p)
                            .onTapGesture { editing = p }
                            .contextMenu { menu(p) }
                    }
                    Button {
                        creating = true
                    } label: {
                        Label("New project", systemImage: "plus")
                            .font(.rounded(17, .bold)).foregroundStyle(DD.ink3)
                            .frame(maxWidth: .infinity, minHeight: 170)
                            .overlay(
                                RoundedRectangle(cornerRadius: DD.Radius.tile, style: .continuous)
                                    .strokeBorder(DD.disabled, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)

                let archived = projects.filter(\.isArchived)
                if !archived.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showArchived.toggle() }
                    } label: {
                        HStack(spacing: 6) {
                            Text("Archived")
                            Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
                                .rotationEffect(.degrees(showArchived ? 90 : 0))
                        }
                        .font(.footnote.weight(.semibold)).foregroundStyle(DD.ink3)
                        .padding(.horizontal, 32).padding(.top, 26).padding(.bottom, 6)
                    }
                    .buttonStyle(.plain)
                    if showArchived {
                        DDGroup {
                            ForEach(archived) { p in
                                HStack(spacing: 12) {
                                    RoundedRectangle(cornerRadius: 4, style: .continuous).fill(p.color).opacity(0.5)
                                        .frame(width: 12, height: 12)
                                    Text(p.name).font(.body)
                                    Spacer()
                                    Text("\(compactHours(p.dailyTargetMinutes))/day").font(.rounded(16, .medium)).monospacedDigit()
                                }
                                .foregroundStyle(DD.ink3)
                                .padding(.horizontal, 16).frame(minHeight: 52)
                                .contentShape(Rectangle())
                                .onTapGesture { editing = p }
                                .contextMenu { menu(p) }
                            }
                        }
                    }
                }
                Text("Archived projects leave Today but keep their history.")
                    .font(.footnote).foregroundStyle(DD.ink3)
                    .padding(.horizontal, 32).padding(.vertical, 10)
            }
            .padding(.bottom, 24)
        }
        .toolbar {
            Button("New Project", systemImage: "plus") { creating = true }
                .buttonStyle(.borderedProminent).tint(DD.forestFill)
        }
    }
    #endif

    @ViewBuilder private func menu(_ p: Project) -> some View {
        Button("Edit") { editing = p }
        Button(p.isArchived ? "Unarchive" : "Archive") { p.isArchived.toggle() }
        Button("Delete…", role: .destructive) { deleting = p }
    }
}

struct ProjectColorTile: View {
    let project: Project
    var height: CGFloat = 170

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(project.name).font(.ddTitle3).lineLimit(1)
            Text(scheduleLabel(project.activeWeekdaysMask)).font(.footnote).opacity(0.75)
            Spacer(minLength: 8)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(compactHours(project.dailyTargetMinutes)).font(.ddStatXL).tracking(-1).monospacedDigit()
                Text("/day").font(.subheadline.weight(.semibold)).opacity(0.75)
            }
            .lineLimit(1).minimumScaleFactor(0.6)
        }
        .foregroundStyle(ink)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: height)
        .background {
            ZStack(alignment: .bottomTrailing) {
                project.color
                Circle().fill(.white.opacity(0.1)).frame(width: 110, height: 110).offset(x: 30, y: 30)
            }
        }
        .clipShape(.dd(DD.Radius.tile))
        .contentShape(.dd(DD.Radius.tile))
    }

    /// Light swatches carry forest text; the rest white. Forest itself turns light in dark mode.
    private var ink: Color {
        switch Palette.canonical(project.colorName) {
        case "seafoam": DD.onMint
        case "forest": Color.dynamic(light: .white, dark: DD.onMint)
        default: .white
        }
    }
}

func scheduleLabel(_ mask: Int) -> String {
    switch mask {
    case Weekdays.all: return "Every day"
    case Weekdays.monToFri: return "Weekdays"
    case 0b100_0001: return "Weekends"
    case 0: return "No days"
    default:
        let cal = Calendar.current
        return (0..<7).map { ($0 + cal.firstWeekday - 1) % 7 }
            .filter { mask & (1 << $0) != 0 }
            .map { cal.shortWeekdaySymbols[$0] }
            .joined(separator: " ")
    }
}

struct ProjectEditor: View {
    let project: Project?
    @Environment(\.modelContext) private var context
    @State private var name = ""
    @State private var colorName = Palette.names[0]
    @State private var targetMinutes = 120
    @State private var mask = Weekdays.monToFri
    @State private var archived = false

    var body: some View {
        EditorSheet(title: project == nil ? "New Project" : "Edit Project", canSave: !name.isBlank, save: save) {
            Section { TextField("Name", text: $name).font(.system(size: 17, weight: .semibold)).labelsHidden() }
            Section {
                ColorChoice(selection: $colorName)
                LabeledContent("Daily target") {
                    HStack(spacing: 8) {
                        Text(compactHours(targetMinutes)).font(.rounded(13, .bold)).monospacedDigit()
                        Stepper("Daily target", value: $targetMinutes, in: 15...(12 * 60), step: 15).labelsHidden()
                    }
                }
                WeekdayPicker(mask: $mask)
                Toggle(isOn: $archived) {
                    Text("Archived")
                    Text("Hidden from Today. Past time stays in Stats.")
                }
            } footer: {
                Text("\(scheduleLabel(mask)) · \(compactHours(targetMinutes)) a day counts as enough.")
            }
        }
        .onAppear {
            guard let project else { return }
            name = project.name
            colorName = project.colorName
            targetMinutes = max(15, project.dailyTargetMinutes)
            mask = project.activeWeekdaysMask
            archived = project.isArchived
        }
    }

    private func save() {
        let p = project ?? Project(name: "")
        p.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        p.colorName = colorName
        p.dailyTargetMinutes = targetMinutes
        p.activeWeekdaysMask = mask
        p.isArchived = archived
        if project == nil { context.insert(p) }
    }
}

#Preview {
    NavigationStack { ProjectsView() }
        .modelContainer(SharedStore.preview)
}
