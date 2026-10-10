//
//  QuickAdd.swift
//  Do-Du
//
//  "Add 2h design review to Do-Du tomorrow" → pre-filled task editor.
//  Parsed on-device with Apple Foundation Models; always confirmed by the user.
//

import SwiftUI
import SwiftData

struct QuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Project> { !$0.isArchived }, sort: \Project.createdAt) private var projects: [Project]
    @Query(sort: \Category.name) private var categories: [Category]
    @State private var text = ""
    @State private var parsing = false
    @State private var note: String?
    @State private var prefill: TaskPrefill?
    @FocusState private var focused: Bool

    var body: some View {
        if let prefill {
            TaskEditor(task: nil, prefill: prefill)
        } else {
            NavigationStack {
                Form {
                    TextField("Add 2h design review to Do-Du tomorrow", text: $text, axis: .vertical)
                        .lineLimit(1...4)
                        .onSubmit(parse)
                        .disabled(parsing)
                        .focused($focused)
                    if parsing { ProgressView("Reading…") }
                    if let note { Text(note).foregroundStyle(.secondary) }
                    if !QuickAddParser.isAvailable {
                        Text("Apple Intelligence isn't available here, so the text becomes the task title.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .formStyle(.grouped)
                .navigationTitle("Quick Add")
                .onAppear { focused = true }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Next", action: parse).disabled(text.isBlank || parsing)
                    }
                }
            }
            #if os(macOS)
            .frame(minWidth: 420, minHeight: 200)
            #endif
        }
    }

    private func parse() {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        guard QuickAddParser.isAvailable else {
            prefill = TaskPrefill(title: input)
            return
        }
        parsing = true
        Task {
            do {
                prefill = try await QuickAddParser.parse(input, projects: projects, categories: categories)
            } catch {
                // Model refused or failed: fall back to plain title rather than blocking.
                prefill = TaskPrefill(title: input)
            }
            parsing = false
        }
    }
}
