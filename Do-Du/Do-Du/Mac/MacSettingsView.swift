#if os(macOS)
import ServiceManagement
import SwiftData
import SwiftUI

struct MacSettingsView: View {
    /// Reopens on the last tab, like system Settings windows.
    @AppStorage("macSettingsTab") private var tab = "general"

    var body: some View {
        TabView(selection: $tab) {
            Tab("General", systemImage: "gearshape", value: "general") { MacGeneralSettings() }
            Tab("Timer", systemImage: "stopwatch", value: "timer") { MacTimerSettings() }
            Tab("Assistant", systemImage: "sparkles", value: "assistant") { MacAssistantSettings() }
            Tab("Data", systemImage: "externaldrive", value: "data") { MacDataSettings() }
        }
        .frame(width: 680)
        .tint(DD.forestFill)
    }
}

private struct SettingsPage<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        Form { Group { content }.ddRows() }
            .ddForm()
            .frame(minHeight: 360)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct ValueStepper: View {
    let title: String
    let value: String
    var subtitle: String?
    let increment: () -> Void
    let decrement: () -> Void

    var body: some View {
        LabeledContent {
            HStack(spacing: 8) {
                Text(value).font(.rounded(13, .bold)).monospacedDigit()
                Stepper(title, onIncrement: increment, onDecrement: decrement).labelsHidden()
            }
        } label: {
            Text(title)
            if let subtitle { Text(subtitle) }
        }
    }
}

struct MacGeneralSettings: View {
    @AppStorage(DayMath.startHourKey) private var dayStartHour = 0
    @AppStorage(MenuBarVisibility.key) private var showMenuBar = true
    @AppStorage(GlobalHotKey.enabledKey) private var hotKeyOn = true
    @State private var openAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        SettingsPage {
            Section("Day") {
                ValueStepper(
                    title: "Day starts at", value: "\(dayStartHour):00",
                    subtitle: "Work before this hour counts toward the previous day.",
                    increment: { dayStartHour = min(6, dayStartHour + 1) },
                    decrement: { dayStartHour = max(0, dayStartHour - 1) })
            }
            Section {
                Toggle("Open at login", isOn: Binding(get: { openAtLogin }, set: setOpenAtLogin))
                Toggle("Show in menu bar", isOn: $showMenuBar)
                Toggle(isOn: $hotKeyOn) {
                    Text("Start or stop with ⌘⇧T")
                    Text("Works from any app. While on, other apps lose ⌘⇧T (e.g. Reopen Tab in browsers).")
                }
                .onChange(of: hotKeyOn) { GlobalHotKey.apply() }
            } header: {
                Text("Mac")
            } footer: {
                if let loginError { Text(loginError).foregroundStyle(DD.danger) }
            }
            CategoriesSection()
        }
    }

    private func setOpenAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = "Couldn’t change login items: \(error.localizedDescription)"
        }
        openAtLogin = SMAppService.mainApp.status == .enabled
    }
}

struct MacTimerSettings: View {
    @AppStorage(IdleStop.minutesKey) private var idleMinutes = IdleStop.defaultMinutes
    @AppStorage(IdleStop.sleepStopKey) private var sleepStop = true
    @AppStorage(IdleStop.screensaverStopKey) private var screensaverStop = false
    @AppStorage(IdleStop.lockStopKey) private var lockStop = false
    @AppStorage(LongRunAlert.thresholdKey) private var longRunHours = LongRunAlert.defaultHours
    @AppStorage(Pomodoro.enabledKey) private var pomodoroOn = false
    @AppStorage(Pomodoro.minutesKey) private var focusMinutes = 25
    @AppStorage(Pomodoro.breakKey) private var breakMinutes = 5

    var body: some View {
        SettingsPage {
            Section {
                ValueStepper(
                    title: "Stop when idle for", value: compactHours(idleMinutes),
                    increment: { idleMinutes = min(60, idleMinutes + 5) },
                    decrement: { idleMinutes = max(5, idleMinutes - 5) })
                Toggle("Stop on sleep", isOn: $sleepStop)
                Toggle("Stop on screensaver", isOn: $screensaverStop)
                Toggle("Stop on lock", isOn: $lockStop)
                ValueStepper(
                    title: "Warn when a timer runs over", value: compactHours(Int(longRunHours * 60)),
                    increment: { longRunHours = min(8, longRunHours + 0.5) },
                    decrement: { longRunHours = max(1, longRunHours - 0.5) })
            } header: {
                Text("Stopping")
            } footer: {
                Text("Idle stops are backdated to your last activity; the rest stop the timer at that moment.")
            }
            Section("Pomodoro") {
                Toggle(isOn: $pomodoroOn) {
                    Text("Pomodoro mode")
                    Text("Work and break intervals on top of the timer.")
                }
                if pomodoroOn {
                    ValueStepper(
                        title: "Focus", value: compactHours(focusMinutes),
                        increment: { focusMinutes = min(90, focusMinutes + 5) },
                        decrement: { focusMinutes = max(10, focusMinutes - 5) })
                    ValueStepper(
                        title: "Break", value: compactHours(breakMinutes),
                        increment: { breakMinutes = min(30, breakMinutes + 1) },
                        decrement: { breakMinutes = max(1, breakMinutes - 1) })
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: pomodoroOn)
    }
}

struct MacAssistantSettings: View {
    @State private var hasKey = ClaudeKey.current != nil
    @State private var adding = false
    @State private var draft = ""

    var body: some View {
        SettingsPage {
            Section {
                LabeledContent {
                    HStack(spacing: 12) {
                        Text(hasKey ? ClaudeKey.masked ?? "Saved" : "Not set")
                            .font(.system(.body, design: .monospaced)).foregroundStyle(DD.ink3)
                        if hasKey {
                            Button("Remove Key", role: .destructive) {
                                ClaudeKey.remove()
                                hasKey = false
                            }
                            .tint(DD.danger)
                        } else {
                            Button("Add Key…") { adding = true }.ddPrimary()
                        }
                    }
                } label: {
                    Text("API key")
                    Text(hasKey ? "Stored in Keychain on this Mac." : "Plan My Day, Recap and Chat need a key.")
                }
            } header: {
                Text("Claude")
            } footer: {
                Text("Quick Add runs on this Mac and works without a key or a connection.")
            }
            CalendarSettingsSection()
        }
        .alert("Add Claude API Key", isPresented: $adding) {
            SecureField("sk-ant-…", text: $draft)
            Button("Cancel", role: .cancel) { draft = "" }
            Button("Save") {
                hasKey = ClaudeKey.save(draft.trimmingCharacters(in: .whitespacesAndNewlines))
                draft = ""
            }
        } message: {
            Text("Stored in your Keychain on this Mac. Get a key at console.anthropic.com.")
        }
    }
}

struct MacDataSettings: View {
    @AppStorage(SharedStore.iCloudKey) private var iCloudOn = true
    @Query private var entries: [TimeEntry]
    @State private var export: CSVDocument?

    var body: some View {
        SettingsPage {
            Section {
                Toggle("Sync with iCloud", isOn: $iCloudOn)
                LabeledContent("Status") {
                    let status = SyncMonitor.shared.summary
                    HStack(spacing: 7) {
                        Circle().fill(status.ok ? DD.mint : .orange).frame(width: 8, height: 8)
                        Text(status.text).multilineTextAlignment(.trailing)
                    }
                }
            } header: {
                Text("iCloud")
            } footer: {
                if iCloudOn != SharedStore.iCloudOnAtLaunch {
                    Text(
                        iCloudOn
                            ? "Sync starts next time you open Do-Du."
                            : "Sync stops next time you open Do-Du. Data already in iCloud stays there.")
                }
            }
            Section("Export") {
                LabeledContent {
                    Button("Export CSV…") { export = CSVDocument(text: TimeEntryCSV.make(entries)) }
                        .disabled(entries.isEmpty)
                } label: {
                    Text("Time entries")
                    Text("Every session as a CSV file.")
                }
            }
            AutoImportSection()
            NotionSettingsSection()
            RemindersSettingsSection()
        }
        .csvExport($export)
    }
}

enum MenuBarVisibility {
    static let key = "showMenuBar"
}
#endif
