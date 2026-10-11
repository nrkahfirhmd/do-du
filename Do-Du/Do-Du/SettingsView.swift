//
//  SettingsView.swift
//  Do-Du
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage(LongRunAlert.thresholdKey) private var longRunHours = LongRunAlert.defaultHours
    @AppStorage(DayMath.startHourKey) private var dayStartHour = 0
    @AppStorage(RecapReminder.enabledKey) private var recapOn = false
    @AppStorage(RecapReminder.minutesKey) private var recapMinutes = 18 * 60
    @AppStorage(Pomodoro.enabledKey) private var pomodoroOn = false
    @AppStorage(Pomodoro.minutesKey) private var pomodoroMinutes = 25
    @AppStorage(Pomodoro.breakKey) private var breakMinutes = 5
    @AppStorage(SharedStore.iCloudKey) private var iCloudOn = true
    @Query private var entries: [TimeEntry]
    @State private var export: CSVDocument?

    var body: some View {
        Form {
            Group {
                Section("Timer") {
                    Picker("Day starts at", selection: $dayStartHour) {
                        ForEach(0...6, id: \.self) { Text(String(format: "%d:00", $0)).tag($0) }
                    }
                    Toggle("Pomodoro break reminder", isOn: $pomodoroOn)
                    if pomodoroOn {
                        Stepper("Focus \(pomodoroMinutes) min", value: $pomodoroMinutes, in: 10...90, step: 5)
                        Stepper("Break \(breakMinutes) min", value: $breakMinutes, in: 1...30)
                    }
                    Stepper("Warn after \(TimeInterval(longRunHours * 3600).hoursMinutes) running",
                            value: $longRunHours, in: 0.5...12, step: 0.5)
                }
                Section("Recap") {
                    Toggle("Daily recap reminder", isOn: $recapOn)
                    if recapOn {
                        DatePicker("Remind at", selection: Binding(
                            get: { Calendar.current.startOfDay(for: .now).addingTimeInterval(Double(recapMinutes) * 60) },
                            set: { recapMinutes = Calendar.current.component(.hour, from: $0) * 60 + Calendar.current.component(.minute, from: $0) }),
                                   displayedComponents: .hourAndMinute)
                    }
                }
                .onChange(of: recapOn) { RecapReminder.apply(enabled: recapOn, minutesAfterMidnight: recapMinutes) }
                .onChange(of: recapMinutes) { RecapReminder.apply(enabled: recapOn, minutesAfterMidnight: recapMinutes) }
                CategoriesSection()
                ClaudeKeySection()
                NotionSettingsSection()
                RemindersSettingsSection()
                CalendarSettingsSection()
                Section {
                    Toggle("Sync with iCloud", isOn: $iCloudOn)
                    if iCloudOn == SharedStore.iCloudOnAtLaunch { ICloudStatus() }
                } header: {
                    Text("Sync")
                } footer: {
                    if iCloudOn != SharedStore.iCloudOnAtLaunch {
                        Text(iCloudOn ? "Sync starts next time you open Do-Du." : "Sync stops next time you open Do-Du. Data already in iCloud stays there.")
                    }
                }
                Section("Data") {
                    Button("Export Time Entries (CSV)…", systemImage: "square.and.arrow.up") {
                        export = CSVDocument(text: TimeEntryCSV.make(entries))
                    }
                    .disabled(entries.isEmpty)
                }
            }
            .ddRows()
        }
        .ddForm()
        .navigationTitle("Settings")
        .csvExport($export)
    }
}

extension View {
    /// Save-panel for the time-entries CSV; `document` non-nil opens it.
    func csvExport(_ document: Binding<CSVDocument?>) -> some View {
        fileExporter(isPresented: .init(get: { document.wrappedValue != nil }, set: { if !$0 { document.wrappedValue = nil } }),
                     document: document.wrappedValue, contentType: .commaSeparatedText,
                     defaultFilename: "Do-Du time entries \(Date.now.formatted(.iso8601.year().month().day()))") { _ in }
    }
}

struct CategoriesSection: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Category.name) private var categories: [Category]
    @State private var editing: Category?
    @State private var creating = false

    var body: some View {
        Section {
            ForEach(categories) { c in
                HStack {
                    ColorDot(color: c.color)
                    Text(c.name)
                    Spacer()
                    Button("Edit") { editing = c }.buttonStyle(.borderless)
                    Button("Delete", systemImage: "trash", role: .destructive) { context.delete(c) }
                        .labelStyle(.iconOnly).buttonStyle(.borderless)
                }
            }
            Button("Add Category", systemImage: "plus") { creating = true }
        } header: {
            Text("Categories")
        } footer: {
            Text("Deleting a category keeps its tasks; they just become uncategorized.")
        }
        .sheet(isPresented: $creating) { CategoryEditor(category: nil) }
        .sheet(item: $editing) { CategoryEditor(category: $0) }
    }
}

struct CategoryEditor: View {
    let category: Category?
    @Environment(\.modelContext) private var context
    @State private var name = ""
    @State private var colorName = Palette.names[0]

    var body: some View {
        EditorSheet(title: category == nil ? "New Category" : "Edit Category", canSave: !name.isBlank) {
            let c = category ?? Category(name: "")
            c.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            c.colorName = colorName
            if category == nil { context.insert(c) }
        } content: {
            TextField("Name", text: $name)
            ColorChoice(selection: $colorName)
        }
        .onAppear {
            name = category?.name ?? ""
            colorName = category?.colorName ?? Palette.names[0]
        }
    }
}

/// iCloud account state. Data always saves locally; it syncs once signed in.
struct ICloudStatus: View {
    var body: some View {
        if !SharedStore.iCloudOnAtLaunch {
            Label("iCloud sync off. Data stays on this device.", systemImage: "icloud.slash")
        } else if FileManager.default.ubiquityIdentityToken != nil {
            Label("iCloud sync on", systemImage: "checkmark.icloud")
        } else {
            Label {
                Text("Not signed in to iCloud. Data is saved on this device only; sign in to sync between devices.")
            } icon: {
                Image(systemName: "icloud.slash").foregroundStyle(.orange)
            }
        }
    }
}

/// Claude API key for Plan, Recap and Chat. Stored only in Keychain.
struct ClaudeKeySection: View {
    @State private var hasKey = ClaudeKey.current != nil
    @State private var draft = ""

    var body: some View {
        Section {
            if hasKey {
                LabeledContent("API key", value: ClaudeKey.masked ?? "Saved")
                Button("Remove Key", role: .destructive) {
                    ClaudeKey.remove()
                    hasKey = false
                }
            } else {
                SecureField("Claude API key", text: $draft)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                Button("Save Key") {
                    hasKey = ClaudeKey.save(draft.trimmingCharacters(in: .whitespacesAndNewlines))
                    draft = ""
                }
                .disabled(draft.isBlank)
            }
        } header: {
            Text("Claude")
        } footer: {
            Text("Used for Plan my day, Recap and Chat. Stored in your Keychain on this device only; get a key at console.anthropic.com.")
        }
    }
}
