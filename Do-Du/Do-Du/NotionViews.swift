//
//  NotionViews.swift
//  Do-Du
//
//  Notion settings. Importing goes through the shared ExternalImportSheet.
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
