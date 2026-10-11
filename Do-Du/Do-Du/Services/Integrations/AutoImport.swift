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
                    await run()
                    try? await Task.sleep(for: Self.interval)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)) { _ in
                ExternalLinks.removeDuplicates(in: context)
            }
    }

    private func run() async {
        // Errors (offline, revoked access) are silent here; the import sheet shows them.
        _ = try? await NotionClient.autoImport(in: context)
        _ = try? await RemindersSource.autoImport(in: context)
        ExternalLinks.removeDuplicates(in: context)
    }
}
