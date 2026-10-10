//
//  NotionViews.swift
//  Do-Du
//
//  One-way import from a single Notion database. New rows are previewed
//  with a project picker; nothing is written before Import is tapped.
//

import SwiftData
import SwiftUI

/// Token (Keychain) + database ID + connection test.
struct NotionSettingsSection: View {
    @State private var hasToken = NotionKey.current != nil
    @State private var draft = ""
    @AppStorage(NotionClient.databaseKey) private var databaseID = ""
    @State private var testing = false
    @State private var testMessage: String?

    var body: some View {
        Section {
            if hasToken {
                LabeledContent("Token", value: NotionKey.masked ?? "Saved")
                Button("Remove Token", role: .destructive) {
                    NotionKey.remove()
                    hasToken = false
                }
            } else {
                SecureField("Notion token (ntn_…)", text: $draft)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                Button("Save Token") {
                    hasToken = NotionKey.save(draft.trimmingCharacters(in: .whitespacesAndNewlines))
                    draft = ""
                }
                .disabled(draft.isBlank)
            }
            TextField("Database ID (or page URL)", text: $databaseID)
                .autocorrectionDisabled()
                .onChange(of: databaseID) {
                    let normal = NotionClient.normalizeDatabaseID(databaseID)
                    if !normal.isEmpty { databaseID = normal }
                    testMessage = nil
                }
            if testing {
                ProgressView("Connecting…")
            } else {
                Button("Test Connection", action: test)
                    .disabled(!hasToken || databaseID.isEmpty)
            }
            if let testMessage { Text(testMessage).foregroundStyle(.secondary) }
        } header: {
            Text("Notion")
        } footer: {
            Text("One-way import from one database (table). Create an internal integration at notion.so/my-integrations, invite it to the page, and paste the token and database ID here.")
        }
    }

    private func test() {
        testing = true
        testMessage = nil
        Task {
            do {
                let n = try await NotionClient.fetchDrafts().count
                testMessage = "Connected — \(n) row\(n == 1 ? "" : "s") found."
            } catch {
                testMessage = error.localizedDescription
            }
            testing = false
        }
    }
}

struct NotionImportSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Project> { !$0.isArchived }, sort: \Project.createdAt) private var projects: [Project]
    @State private var drafts: [ExternalDraft] = []
    @State private var included = Set<String>()
    @State private var picks: [String: String] = [:]
    @State private var loading = true
    @State private var error: String?
    @State private var result: String?

    var body: some View {
        NavigationStack {
            List {
                if loading {
                    ProgressView("Reading Notion…")
                } else if let error {
                    Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                    Button("Try Again", action: load)
                } else if drafts.isEmpty {
                    Text("Nothing new — every Notion row is already linked.").foregroundStyle(.secondary)
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
                        Text("Rows already linked refresh automatically (title, status, due date). Nothing is saved until you import.")
                    }
                }
                if let result {
                    Section { Text(result).foregroundStyle(.secondary) }
                }
            }
            .navigationTitle("Import from Notion")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(result == nil ? "Cancel" : "Done") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") { importSelected() }
                        .disabled(loading || error != nil || included.isEmpty)
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
        if d.isDone { parts.append("done in Notion") }
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
                let all = try await NotionClient.fetchDrafts()
                let linked = Set(((try? context.fetch(FetchDescriptor<TaskItem>())) ?? [])
                    .filter { $0.externalSource == NotionClient.id }.compactMap(\.externalID))
                drafts = all.filter { !linked.contains($0.externalID) }
                included = Set(drafts.map(\.externalID))
                for d in drafts {
                    picks[d.externalID] = NotionClient.resolveProject(d.projectName, in: projects)?.name
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
        let r = NotionClient.apply(chosen, projects: projects, in: context)
        var parts = ["Imported \(r.inserted)"]
        if r.updated > 0 { parts.append("updated \(r.updated)") }
        if r.skipped > 0 { parts.append("skipped \(r.skipped) (no matching project)") }
        result = parts.joined(separator: ", ") + "."
        included = []
    }
}

private extension Set where Element == String {
    mutating func insertOrRemove(_ member: String, _ insert: Bool) {
        if insert { self.insert(member) } else { self.remove(member) }
    }
}
