import SwiftData
import SwiftUI

/// Today's sessions, newest first. Finished ones can be deleted (context menu; trash on hover on Mac) with an inline Undo.
struct SessionsCard: View {
    let entries: [TimeEntry]
    let now: Date
    @Environment(\.modelContext) private var context
    @State private var deleted: TimerService.DeletedSession?

    var body: some View {
        if !entries.isEmpty || deleted != nil {
            VStack(alignment: .leading, spacing: 0) {
                Text("Sessions today").font(.footnote.weight(.semibold)).foregroundStyle(DD.ink3)
                    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 6)
                if deleted != nil { undoRow.transition(.move(edge: .top).combined(with: .opacity)) }
                ForEach(entries, id: \.persistentModelID) { e in
                    SessionRow(entry: e, now: now) { delete(e) }
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                }
            }
            .padding(.bottom, 6)
            .background(DD.surface, in: .dd(DD.Radius.card))
            .clipShape(.dd(DD.Radius.card))
            .animation(DD.listChange, value: entries.map(\.persistentModelID))
            .animation(DD.listChange, value: deleted != nil)
            // Undo stays for a few seconds, then the delete is final.
            .task(id: deleted?.start) {
                guard deleted != nil else { return }
                try? await Task.sleep(for: .seconds(6))
                deleted = nil
            }
        }
    }

    private var undoRow: some View {
        HStack {
            Label("Session deleted", systemImage: "trash").font(.subheadline).foregroundStyle(DD.ink3)
            Spacer()
            Button("Undo") {
                if let deleted { TimerService.restore(deleted, in: context) }
                deleted = nil
            }
            .buttonStyle(CapsuleButton(fill: DD.forestFill, ink: .white, height: 28))
            .keyboardShortcut("z", modifiers: .command)
        }
        .padding(.horizontal, 16).frame(minHeight: 44)
    }

    private func delete(_ e: TimeEntry) {
        deleted = TimerService.delete(e, in: context)
    }
}

private struct SessionRow: View {
    let entry: TimeEntry
    let now: Date
    let onDelete: () -> Void
    @State private var hovering = false

    var body: some View {
        let e = entry
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(e.effectiveProject?.color ?? DD.disabled).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 0) {
                Text(e.effectiveProject?.name ?? "No project").font(.subheadline.weight(.semibold))
                Text(e.title).font(.caption).foregroundStyle(e.isRunning ? DD.onMint.opacity(0.7) : DD.ink3)
            }
            .lineLimit(1)
            Spacer()
            Text(
                "\(e.start.formatted(date: .omitted, time: .shortened))–\(e.end?.formatted(date: .omitted, time: .shortened) ?? "now")"
            )
            .font(.caption).monospacedDigit().foregroundStyle(e.isRunning ? DD.onMint.opacity(0.7) : DD.ink3)
            Text(e.duration(now: now).hoursMinutes).font(.rounded(14, .semibold)).monospacedDigit()
                .frame(width: 64, alignment: .trailing)
            #if os(macOS)
            if !e.isRunning {
                Button("Delete Session", systemImage: "trash", action: onDelete)
                    .labelStyle(.iconOnly).buttonStyle(.plain).foregroundStyle(DD.danger)
                    .opacity(hovering ? 1 : 0)
                    .help("Delete Session")
            }
            #endif
        }
        .foregroundStyle(e.isRunning ? DD.onMint : DD.ink)
        .padding(.horizontal, 16).frame(minHeight: 44)
        .background(e.isRunning ? DD.mint : hovering ? DD.fill.opacity(0.6) : .clear)
        .contentShape(Rectangle())
        .onHover { h in withAnimation(DD.hover) { hovering = h } }
        .contextMenu {
            if e.isRunning {
                Text("Stop the timer to delete this session")
            } else {
                Button("Delete Session", systemImage: "trash", role: .destructive, action: onDelete)
            }
        }
    }
}
