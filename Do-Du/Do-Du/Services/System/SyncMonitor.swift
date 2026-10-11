import CloudKit
import CoreData
import Foundation
import Observation

/// Last CloudKit sync result; SwiftData mirrors through NSPersistentCloudKitContainer, which posts these events.
@Observable
final class SyncMonitor {
    static let shared = SyncMonitor()

    private(set) var lastSuccess: Date?
    private(set) var lastError: String?
    private(set) var lastErrorDate: Date?
    @ObservationIgnored private var token: NSObjectProtocol?

    /// Call before the store opens; setup events fire right away.
    func start() {
        guard token == nil else { return }
        token = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main
        ) { note in
            guard
                let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event, let end = event.endDate
            else { return }
            let error = event.error.map(Self.describe)
            MainActor.assumeIsolated { SyncMonitor.shared.record(end: end, error: error) }
        }
    }

    func record(end: Date, error: String?) {
        if let error {
            lastError = error
            lastErrorDate = end
        } else {
            lastSuccess = end
        }
    }

    /// The latest event failed.
    var failing: Bool {
        guard let lastErrorDate else { return false }
        return lastErrorDate > (lastSuccess ?? .distantPast)
    }

    /// One line for Settings; `ok` false means sync isn't working on this device.
    var summary: (ok: Bool, text: String) {
        if !SharedStore.iCloudOnAtLaunch { return (false, "Off. Data stays on this device.") }
        if FileManager.default.ubiquityIdentityToken == nil { return (false, "Not signed in to iCloud") }
        if failing, let lastError { return (false, lastError) }
        if let lastSuccess { return (true, "Synced \(lastSuccess.formatted(.relative(presentation: .named)))") }
        return (true, "On, waiting for first sync")
    }

    nonisolated static func describe(_ error: Error) -> String {
        guard let ck = error as? CKError else { return error.localizedDescription }
        switch ck.code {
        case .notAuthenticated: return "Not signed in to iCloud."
        case .quotaExceeded: return "iCloud storage is full."
        case .networkUnavailable, .networkFailure: return "No connection. Sync resumes when online."
        // Production containers never create record types; the schema must be deployed from the CloudKit Console.
        case .partialFailure where ck.partialErrorsByItemID?.isEmpty == false:
            return describe(ck.partialErrorsByItemID!.values.first!)
        case .unknownItem, .serverRejectedRequest, .invalidArguments, .partialFailure:
            return "iCloud rejected the data (CKError \(ck.code.rawValue)). The CloudKit schema may not be deployed to Production."
        default: return "\(ck.localizedDescription) (CKError \(ck.code.rawValue))"
        }
    }
}
