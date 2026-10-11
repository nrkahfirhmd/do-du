import EventKit
import SwiftData
import SwiftUI

struct ExternalImportSheet<Source: TaskSource>: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Project> { !$0.isArchived }, sort: \Project.createdAt) private var projects: [Project]
    @State private var drafts: [ExternalDraft] = []
    @State private var linked: [ExternalDraft] = []
    @State private var included = Set<String>()
    @State private var picks: [String: String] = [:]
    @State private var loading = true
    @State private var error: String?
    @State private var result: String?

    var body: some View {
        NavigationStack {
            List {
                Group {
                    if loading {
                        ProgressView("Reading \(Source.displayName)…")
                    } else if let error {
                        Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                        Button("Try Again", action: load)
                    } else if drafts.isEmpty {
                        Text("Nothing new in \(Source.displayName).").foregroundStyle(.secondary)
                    } else {
                        Section {
                            ForEach(drafts) { d in
                                Toggle(isOn: Binding(
                                    get: { included.contains(d.externalID) },
                                    set: { included.insertOrRemove(d.externalID, $0) })) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(d.title).lineLimit(2)
                                        Text(rowSubtitle(d)).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Picker("Project", selection: Binding(
                                    get: { picks[d.externalID] ?? "" },
                                    set: { picks[d.externalID] = $0 })) {
                                    ForEach(projects.map(\.name), id: \.self) { Text($0) }
                                }
                                .pickerStyle(.menu)
                            }
                        } footer: {
                            Text("Finished items aren't offered. Nothing is saved until you import.")
                        }
                    }
                    if !loading, error == nil, !linked.isEmpty {
                        Section {
                            Text("\(linked.count) linked task\(linked.count == 1 ? "" : "s") will refresh title, done and due date.")
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let result {
                        Section { Text(result).foregroundStyle(.secondary) }
                    }
                            }
                .ddRows()
            }
            .ddForm()
            .navigationTitle("Import from \(Source.displayName)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(result == nil ? "Cancel" : "Done") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") { importSelected() }
                        .ddPrimary()
                        .disabled(loading || error != nil || result != nil || (included.isEmpty && linked.isEmpty))
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 420)
        #endif
        .task { load() }
    }

    private func rowSubtitle(_ d: ExternalDraft) -> String {
        var parts: [String] = []
        if let due = d.dueDate { parts.append("due " + due.formatted(date: .abbreviated, time: .omitted)) }
        if let p = d.projectName, !p.isEmpty { parts.append(p) }
        return parts.joined(separator: " · ")
    }

    private func load() {
        loading = true
        error = nil
        result = nil
        Task {
            do {
                let split = Source.split(try await Source.fetchDrafts(),
                                         tasks: (try? context.fetch(FetchDescriptor<TaskItem>())) ?? [])
                drafts = split.new
                linked = split.linked
                included = Set(drafts.map(\.externalID))
                for d in drafts {
                    picks[d.externalID] = Source.resolveProject(d.projectName, in: projects)?.name
                        ?? projects.first?.name ?? ""
                }
            } catch {
                self.error = error.localizedDescription
            }
            loading = false
        }
    }

    private func importSelected() {
        let chosen = drafts.filter { included.contains($0.externalID) }.map { d -> ExternalDraft in
            var c = d
            c.projectName = picks[d.externalID] ?? d.projectName
            return c
        }
        // Linked rows go along so changes made in the source reach their tasks.
        let r = Source.apply(chosen + linked, projects: projects, in: context)
        var parts = ["Imported \(r.inserted)"]
        if r.updated > 0 { parts.append("updated \(r.updated)") }
        if r.skipped > 0 { parts.append("skipped \(r.skipped) (no matching project)") }
        result = parts.joined(separator: ", ") + "."
        included = []
    }
}

struct RemindersSettingsSection: View {
    @State private var status = EKEventStore.authorizationStatus(for: .reminder)

    var body: some View {
        Section {
            switch status {
            case .notDetermined:
                Button("Allow Reminders Access") {
                    Task {
                        _ = await RemindersSource.requestAccess()
                        status = EKEventStore.authorizationStatus(for: .reminder)
                    }
                }
            case .fullAccess:
                Label("Reminders connected", systemImage: "checkmark.circle")
            default:
                Text("Reminders access is off. Turn it on in System Settings to import.")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Reminders")
        } footer: {
            Text("One-way import from Tasks → Import. Each list matches a project with the same name; others get a project picker. Nothing is written back to Reminders.")
        }
    }
}

private extension Set where Element == String {
    mutating func insertOrRemove(_ member: String, _ insert: Bool) {
        if insert { self.insert(member) } else { self.remove(member) }
    }
}
