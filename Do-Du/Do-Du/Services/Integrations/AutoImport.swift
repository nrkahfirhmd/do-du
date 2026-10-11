import CoreData
import SwiftData
import SwiftUI

/// Imports Notion and Reminders while the app is active: on activation, then every 15 minutes.
struct AutoImport: ViewModifier {
    static let enabledKey = "autoImportOn"
    static let interval: Duration = .seconds(15 * 60)

    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(enabledKey) private var enabled = true

    func body(content: Content) -> some View {
        content
            .task(id: scenePhase == .active && enabled) {
                guard scenePhase == .active, enabled else { return }
                while !Task.isCancelled {
                    // Errors (offline, revoked access) stay quiet here; manual refresh and the import sheet show them.
                    _ = await ManualRefresh.run(in: context)
                    try? await Task.sleep(for: Self.interval)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)) { _ in
                ExternalLinks.removeDuplicates(in: context)
            }
    }
}

/// Pull to refresh (iPhone) and ⌘R (Mac). CloudKit has no "sync now": saving pushes pending changes,
/// and pulls arrive by push notification, so the result reports the last sync instead.
enum ManualRefresh {
    static let didRun = Notification.Name("doduManualRefresh")

    static func run(in context: ModelContext) async -> String {
        var added = 0
        var problems: [String] = []
        do { added += try await NotionClient.autoImport(in: context) } catch { problems.append("Notion: \(error.localizedDescription)") }
        do { added += try await RemindersSource.autoImport(in: context) } catch {
            problems.append("Reminders: \(error.localizedDescription)")
        }
        ExternalLinks.removeDuplicates(in: context)
        try? context.save()
        NotificationCenter.default.post(name: didRun, object: nil)
        var parts = [added == 0 ? "Up to date" : "\(added) imported"]
        parts += problems
        parts.append(SyncMonitor.shared.summary.text)
        return parts.joined(separator: " · ")
    }
}

/// Shows a refresh result briefly at the top; iPhone also gets pull to refresh.
struct RefreshBanner: ViewModifier {
    @Binding var note: String?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let note {
                    Text(note)
                        .font(.footnote.weight(.semibold)).foregroundStyle(DD.ink)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(DD.surface, in: Capsule())
                        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
                        .padding(.top, 8).padding(.horizontal, 16)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(DD.listChange, value: note)
            .task(id: note) {
                guard note != nil else { return }
                try? await Task.sleep(for: .seconds(4))
                note = nil
            }
    }
}

extension View {
    /// iPhone pull to refresh plus the result banner.
    func pullToRefresh(_ note: Binding<String?>, in context: ModelContext) -> some View {
        #if os(iOS)
        refreshable { note.wrappedValue = await ManualRefresh.run(in: context) }
            .modifier(RefreshBanner(note: note))
        #else
        modifier(RefreshBanner(note: note))
        #endif
    }
}
