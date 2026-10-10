//
//  Components.swift
//  Do-Du
//
//  Small reusable controls.
//

import SwiftUI

struct ColorChoice: View {
    @Binding var selection: String

    var body: some View {
        LabeledContent("Color") {
            HStack(spacing: 6) {
                ForEach(Palette.names, id: \.self) { name in
                    Button { selection = name } label: {
                        Circle()
                            .fill(Palette.color(name))
                            .frame(width: 18, height: 18)
                            .overlay { if selection == name { Circle().stroke(.primary, lineWidth: 2).padding(-3) } }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(name)
                    .accessibilityAddTraits(selection == name ? .isSelected : [])
                }
            }
        }
    }
}

struct WeekdayPicker: View {
    @Binding var mask: Int

    var body: some View {
        let cal = Calendar.current
        let symbols = cal.veryShortWeekdaySymbols
        // Display order follows the user's first weekday; bits stay in Calendar order.
        let order = (0..<7).map { ($0 + cal.firstWeekday - 1) % 7 }
        LabeledContent("Active days") {
            HStack(spacing: 4) {
                ForEach(order, id: \.self) { i in
                    let on = mask & (1 << i) != 0
                    Button { mask ^= 1 << i } label: {
                        Text(symbols[i])
                            .frame(width: 26, height: 26)
                            .background(on ? Color.accentColor : Color.secondary.opacity(0.15), in: Circle())
                            .foregroundStyle(on ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(cal.weekdaySymbols[i])
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
    }
}

struct ColorDot: View {
    let color: Color
    var body: some View { Circle().fill(color).frame(width: 10, height: 10) }
}

/// Sheet chrome shared by all editors: Cancel / Save toolbar, Save disabled until valid.
struct EditorSheet<Content: View>: View {
    let title: String
    let canSave: Bool
    let save: () -> Void
    @ViewBuilder let content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form { content }
                .formStyle(.grouped)
                .navigationTitle(title)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { save(); dismiss() }.disabled(!canSave)
                    }
                }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 320)
        #endif
    }
}

extension String {
    var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
