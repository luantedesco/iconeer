import UserNotifications

// System notifications for failures that happen with nobody looking at the window.
@MainActor
final class Notifier {
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
    }

    func post(_ text: String) {
        let content = UNMutableNotificationContent()
        content.title = "Iconeer"
        content.body = text
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}
