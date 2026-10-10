//
//  LongRunAlert.swift
//  Do-Du
//
//  Local notification when a timer runs past the threshold, so a forgotten
//  timer doesn't silently inflate stats.
//

import Foundation
import SwiftData
import UserNotifications

enum LongRunAlert {
    static let thresholdKey = "longRunHours"
    static let defaultHours = 3.0
    private static let requestID = "long-run"
    private static let categoryID = "LONG_RUN"
    fileprivate static let stopAction = "STOP_NOW"
    fileprivate static let keepAction = "KEEP_GOING"
    private static var delegate: Delegate?

    static var thresholdHours: Double {
        UserDefaults.standard.object(forKey: thresholdKey) as? Double ?? defaultHours
    }

    static func register(container: ModelContainer) {
        let center = UNUserNotificationCenter.current()
        center.setNotificationCategories([UNNotificationCategory(
            identifier: categoryID,
            actions: [
                UNNotificationAction(identifier: stopAction, title: "Stop now", options: .destructive),
                UNNotificationAction(identifier: keepAction, title: "Keep going"),
            ],
            intentIdentifiers: [])])
        delegate = Delegate(container: container)
        center.delegate = delegate
        TimerService.onChange = { schedule(from: $0) }
    }

    /// Replaces any pending alert. `nil` cancels. Tapping the notification opens the app,
    /// where the entry can be edited ("stop at…").
    static func schedule(from start: Date?) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [requestID])
        guard let start else { return }
        let fireIn = start.addingTimeInterval(thresholdHours * 3600).timeIntervalSinceNow
        guard fireIn > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Timer still running"
        content.body = "Running for \(TimeInterval(thresholdHours * 3600).hoursMinutes). Forgot to stop it?"
        content.categoryIdentifier = categoryID
        content.sound = .default
        let request = UNNotificationRequest(identifier: requestID, content: content,
                                            trigger: UNTimeIntervalNotificationTrigger(timeInterval: fireIn, repeats: false))
        Task {
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
            try? await center.add(request)
        }
    }

    private final class Delegate: NSObject, UNUserNotificationCenterDelegate {
        let container: ModelContainer
        init(container: ModelContainer) { self.container = container }

        nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                                didReceive response: UNNotificationResponse) async {
            let action = response.actionIdentifier
            await MainActor.run {
                switch action {
                case LongRunAlert.stopAction: TimerService.stop(in: container.mainContext)
                case LongRunAlert.keepAction: LongRunAlert.schedule(from: .now)
                default: break
                }
            }
        }

        nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                                willPresent notification: UNNotification) async
            -> UNNotificationPresentationOptions { [.banner, .sound] }
    }
}
