import SwiftUI

struct ColorChoice: View {
    @Binding var selection: String

    var body: some View {
        LabeledContent("Colour") {
            HStack(spacing: 8) {
                ForEach(Palette.names, id: \.self) { name in
                    Button {
                        selection = name
                    } label: {
                        Circle()
                            .fill(Palette.color(name))
                            .frame(width: 22, height: 22)
                            .padding(3)
                            .overlay(
                                Circle().strokeBorder(Palette.canonical(selection) == name ? Palette.color(name) : .clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(name)
                    .accessibilityAddTraits(Palette.canonical(selection) == name ? .isSelected : [])
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
        LabeledContent("Scheduled on") {
            HStack(spacing: 6) {
                ForEach(order, id: \.self) { i in
                    let on = mask & (1 << i) != 0
                    Button {
                        mask ^= 1 << i
                    } label: {
                        Text(symbols[i]).font(.rounded(13, .bold))
                            .frame(width: 30, height: 30)
                            .background(on ? DD.forestFill : DD.fill, in: Circle())
                            .foregroundStyle(on ? .white : DD.ink3)
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

struct EditorSheet<Content: View>: View {
    let title: String
    let canSave: Bool
    let save: () -> Void
    /// Mac footer, left (e.g. "Delete Task"); the sheet closes after it runs.
    var destructive: (title: String, action: () -> Void)?
    @ViewBuilder let content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        #if os(macOS)
        MacSheet(
            title: title, primary: "Save", primaryHint: "⌘S", primaryKey: KeyboardShortcut("s"),
            canSubmit: canSave,
            submit: {
                save()
                dismiss()
            }
        ) {
            Form { content.ddRows() }.ddForm()
        } footer: {
            if let destructive {
                Button(destructive.title) {
                    destructive.action()
                    dismiss()
                }
                .buttonStyle(.plain).font(.system(size: 13, weight: .semibold)).foregroundStyle(DD.danger)
            }
        }
        #else
        NavigationStack {
            Form { content.ddRows() }
                .ddForm()
                .navigationTitle(title)
                #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.tint(DD.ink) }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            save()
                            dismiss()
                        }.ddPrimary().disabled(!canSave)
                    }
                }
        }
        #endif
    }
}

#if os(macOS)
struct MacSheet<Content: View, Footer: View>: View {
    let title: String
    var subtitle: String?
    var cancel = "Cancel"
    let primary: String
    let primaryHint: String
    let primaryKey: KeyboardShortcut
    let canSubmit: Bool
    let submit: () -> Void
    var width: CGFloat = 560
    @ViewBuilder let content: Content
    @ViewBuilder var footer: Footer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.rounded(22)).foregroundStyle(DD.forest)
                if let subtitle { Text(subtitle).font(.system(size: 13)).foregroundStyle(DD.ink3) }
            }
            .padding(EdgeInsets(top: 22, leading: 24, bottom: 4, trailing: 24))
            content
                .scrollDisabled(true)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                footer
                Spacer(minLength: 8)
                Button(cancel) { dismiss() }
                    .buttonStyle(CapsuleButton(fill: DD.sheetButton, ink: DD.ink))
                    .keyboardShortcut(.cancelAction)
                Button("\(primary)  \(primaryHint)", action: submit)
                    .buttonStyle(CapsuleButton(fill: canSubmit ? DD.forestFill : DD.disabled, ink: .white))
                    .keyboardShortcut(primaryKey)
                    .disabled(!canSubmit)
            }
            .padding(EdgeInsets(top: 8, leading: 20, bottom: 18, trailing: 20))
        }
        .frame(width: width)
        .background(DD.page)
    }
}

extension MacSheet where Footer == EmptyView {
    init(
        title: String, subtitle: String? = nil, cancel: String = "Cancel", primary: String, primaryHint: String,
        primaryKey: KeyboardShortcut, canSubmit: Bool, submit: @escaping () -> Void, width: CGFloat = 560,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title: title, subtitle: subtitle, cancel: cancel, primary: primary, primaryHint: primaryHint,
            primaryKey: primaryKey, canSubmit: canSubmit, submit: submit, width: width,
            content: content, footer: { EmptyView() })
    }
}
#endif

extension String {
    var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

// App-only: UIApplication isn't available to the widget extension, which shares DesignComponents.swift.
extension View {
    func ddForm() -> some View {
        self.formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(DD.page)
            .tint(DD.sage)
            .toggleStyle(MintSwitch())
            .keyboardDismissable()
    }

    /// iPhone: scroll or tap Done to hide the keyboard (number pads and multi-line fields have no Return).
    @ViewBuilder func keyboardDismissable() -> some View {
        #if os(iOS)
        scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done", action: dismissKeyboard).fontWeight(.semibold)
                }
            }
        #else
        self
        #endif
    }
}

#if os(iOS)
func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
#endif

struct CapsuleButton: ButtonStyle {
    let fill: Color
    let ink: Color
    var height: CGFloat = 30

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold)).foregroundStyle(ink)
            .padding(.horizontal, height == 30 ? 14 : 12).frame(height: height)
            .background(fill, in: Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(DD.hover, value: configuration.isPressed)
            .contentShape(Capsule())
            .hoverLift(1.03)
    }
}
