import SwiftUI

/// Due date as a chip; tapping opens quick picks and an app-tinted calendar. nil = no due date.
struct DueDateField: View {
    @Binding var date: Date?
    @State private var picking = false

    var body: some View {
        Button {
            picking = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                Text(date.map { DayMath.dueLabel($0) } ?? "None")
            }
        }
        .buttonStyle(CapsuleButton(fill: date == nil ? DD.fill : DD.mint, ink: date == nil ? DD.ink3 : DD.onMint))
        .popover(isPresented: $picking, arrowEdge: .top) {
            picker.presentationCompactAdaptation(.popover)
        }
    }

    private var picker: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                ForEach(DayMath.dueQuickPicks(), id: \.name) { pick in
                    let on = date.map { Calendar.current.isDate($0, inSameDayAs: pick.day) } ?? false
                    Button(pick.name) { choose(pick.day) }
                        .buttonStyle(CapsuleButton(fill: on ? DD.forestFill : DD.fill, ink: on ? .white : DD.ink))
                }
            }
            DatePicker(
                "Due",
                selection: Binding(
                    get: { date ?? DayMath.logicalDate(.now) },
                    set: { choose($0) }),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .tint(DD.sage)
            if date != nil {
                Button("No due date", role: .destructive) {
                    date = nil
                    picking = false
                }
                .buttonStyle(CapsuleButton(fill: DD.fill, ink: DD.danger))
            }
        }
        .padding(16)
        .frame(width: 320)
        .background(DD.page)
    }

    private func choose(_ day: Date) {
        date = Calendar.current.startOfDay(for: day)
        picking = false
    }
}
