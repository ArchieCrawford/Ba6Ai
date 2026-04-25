import Foundation
import UserNotifications

/// Thin wrapper around `UNUserNotificationCenter` so callers don't
/// have to deal with completion handlers and option sets. Use for
/// memory reminders, scheduled summaries, and "long generation
/// finished" pings.
@MainActor
public final class NotificationService {
    public static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()

    private init() {}

    public func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    public func scheduleReminder(
        id: String = UUID().uuidString,
        title: String,
        body: String,
        after seconds: TimeInterval
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(request)
    }

    public func notifyNow(title: String, body: String) async {
        await scheduleReminder(title: title, body: body, after: 1)
    }

    public func cancel(id: String) {
        center.removePendingNotificationRequests(withIdentifiers: [id])
    }

    public func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}
