import Foundation
import SwiftData

enum IdleStop {
    static let sleepStopKey = "sleepStopOn"
    static let screensaverStopKey = "screensaverStopOn"
    static let lockStopKey = "lockStopOn"
    static let minutesKey = "idleStopMinutes"
    static let defaultMinutes = 10
    static let pollInterval: TimeInterval = 60

    static var stopsOnSleep: Bool {
        UserDefaults.standard.object(forKey: sleepStopKey) as? Bool ?? true
    }

    /// Opt-in: screensaver and display sleep leave the timer running by default.
    static var stopsOnScreensaver: Bool {
        UserDefaults.standard.object(forKey: screensaverStopKey) as? Bool ?? false
    }

    /// Opt-in: lock and fast user switching leave the timer running by default.
    static var stopsOnLock: Bool {
        UserDefaults.standard.object(forKey: lockStopKey) as? Bool ?? false
    }

    static var threshold: TimeInterval {
        TimeInterval(UserDefaults.standard.object(forKey: minutesKey) as? Int ?? defaultMinutes) * 60
    }

    static func stopDate(now: Date, idleSeconds: TimeInterval, thresholdSeconds: TimeInterval) -> Date? {
        guard thresholdSeconds > 0, idleSeconds >= thresholdSeconds else { return nil }
        return now.addingTimeInterval(-idleSeconds)
    }
}

#if os(macOS)
import AppKit
import CoreGraphics
import UserNotifications

extension IdleStop {
    private static var timer: Timer?
    private static var observers: [NSObjectProtocol] = []
    private static var container: ModelContainer?

    static func register(container: ModelContainer) {
        self.container = container
        let center = NSWorkspace.shared.notificationCenter
        observers.append(
            center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { _ in
                Task { @MainActor in stopForEvent(allowed: stopsOnSleep, reason: "went to sleep") }
            })
        // Screensaver and lock stop only when their switches are on.
        observers.append(
            center.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { _ in
                Task { @MainActor in stopForEvent(allowed: stopsOnScreensaver, reason: "started the screensaver") }
            })
        observers.append(
            center.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main) { _ in
                Task { @MainActor in stopForEvent(allowed: stopsOnLock, reason: "was locked") }
            })
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { _ in
            Task { @MainActor in checkIdle() }
        }
    }

    static func idleSeconds() -> TimeInterval {
        // kCGAnyInputEventType ((CGEventType)(~0)): seconds since any mouse, key or tablet activity.
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
    }

    @MainActor private static func stopForEvent(allowed: Bool, reason: String) {
        guard allowed, let container, TimerService.current(in: container.mainContext) != nil else { return }
        TimerService.stop(in: container.mainContext, at: .now)
        notify(body: "Mac \(reason), so the running timer was stopped.")
    }

    @MainActor private static func checkIdle(now: Date = .now) {
        guard let container,
            let running = TimerService.current(in: container.mainContext)
        else { return }
        let idle = idleSeconds()
        guard let stopAt = stopDate(now: now, idleSeconds: idle, thresholdSeconds: threshold),
            stopAt > running.start
        else { return }
        TimerService.stop(in: container.mainContext, at: stopAt)
        notify(
            body: "No activity for \(Int(idle / 60))m, so the timer was stopped at \(stopAt.formatted(date: .omitted, time: .shortened)).")
    }

    private static func notify(body: String) {
        let content = UNMutableNotificationContent()
        content.title = "Timer stopped"
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: "idle-stop", content: content, trigger: nil)
        Task {
            let center = UNUserNotificationCenter.current()
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
            try? await center.add(request)
        }
    }
}
#endif
