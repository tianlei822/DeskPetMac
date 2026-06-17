import Foundation
import UserNotifications

struct BreakNotificationService {
    func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    func showBreakReminder() {
        let content = UNMutableNotificationContent()
        content.title = "DeskPet says: stretch time"
        content.body = "Stand up, roll your shoulders, and give your eyes a minute off the screen."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "DeskPet.break.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
