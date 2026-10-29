//
//  NotificationManager.swift
//  SleepApp
//

import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    func scheduleAllReminders() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [
            "eveningLogReminder",
            "midDayCheckInEarly",
            "midDayCheckInLate"
        ])

        scheduleDaily(
            identifier: "eveningLogReminder",
            hour: 21,
            minute: 30,
            title: "Don't forget tonight's log",
            body: "You haven't logged your sleep yet today. Keep your streak going!"
        )

        scheduleDaily(
            identifier: "midDayCheckInEarly",
            hour: 13,
            minute: 0,
            title: "How are you feeling?",
            body: "Take a moment to check in with Somna."
        )

        scheduleDaily(
            identifier: "midDayCheckInLate",
            hour: 17,
            minute: 30,
            title: "Quick check-in",
            body: "How's your energy this afternoon?"
        )
    }
    
    func scheduleWeeklySummary(averageMinutes: Int, percentChange: Int?) {
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: ["weeklySummary"])

            guard averageMinutes > 0 else { return }

            let hours = averageMinutes / 60
            let mins = averageMinutes % 60
            let durationText = "\(hours)h \(mins)m"

            var body = "You averaged \(durationText) per night last week."
            if let change = percentChange {
                let direction = change >= 0 ? "more" : "less"
                body += " That's \(abs(change))% \(direction) than the week before."
            }

            let content = UNMutableNotificationContent()
            content.title = "Your Week in Sleep"
            content.body = body
            content.sound = .default
            content.userInfo = ["destination": "weeklyReport"]

            var dateComponents = DateComponents()
            dateComponents.weekday = 2 // Pazartesi (1: Pazar, 2: Pazartesi)
            dateComponents.hour = 9
            dateComponents.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: "weeklySummary", content: content, trigger: trigger)

            center.add(request)
        }

    func cancelAllReminders() {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
                "eveningLogReminder",
                "midDayCheckInEarly",
                "midDayCheckInLate",
                "weeklySummary"
            ])
        }

    private func scheduleDaily(identifier: String, hour: Int, minute: Int, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }
}
