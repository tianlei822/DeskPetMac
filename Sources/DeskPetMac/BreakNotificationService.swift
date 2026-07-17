import Foundation
import UserNotifications

struct BreakNotificationService {
    private var canUseUserNotifications: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    func requestAuthorization() async {
        guard canUseUserNotifications else { return }
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    func showBreakReminder() {
        guard canUseUserNotifications else { return }
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
