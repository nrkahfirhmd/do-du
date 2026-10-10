//
//  CalendarViews.swift
//  Do-Du
//

import EventKit
import SwiftUI

/// One read-only calendar: permission status + picker.
struct CalendarSettingsSection: View {
    @AppStorage(CalendarAccess.calendarKey) private var calendarID = ""
    @State private var status = EKEventStore.authorizationStatus(for: .event)
    @State private var options: [(id: String, title: String)] = []

    var body: some View {
        Section {
            switch status {
            case .notDetermined:
                Button("Allow Calendar Access") { Task { await request() } }
            case .fullAccess:
                if options.isEmpty {
                    Text("No calendars found.").foregroundStyle(.secondary)
                } else {
                    Picker("Calendar", selection: $calendarID) {
                        Text("None").tag("")
                        ForEach(options, id: \.id) { Text($0.title).tag($0.id) }
                    }
                }
            default:
                Text("Calendar access is off. Turn it on in System Settings to see meetings in Today.")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Calendar")
        } footer: {
            Text("One calendar, read-only. Today's events appear in Today and meeting time shapes the day plan.")
        }
        .task { await reload() }
    }

    private func request() async {
        _ = await CalendarAccess.requestAccess()
        await reload()
    }

    private func reload() async {
        status = CalendarAccess.authorization()
        options = await CalendarAccess.calendars()
        if !calendarID.isEmpty && !options.contains(where: { $0.id == calendarID }) {
            calendarID = ""
        }
    }
}
