import Foundation
import UserNotifications

@MainActor
final class UsageAlertManager {
    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults
    private let historyKey = "usageAlertHistory"

    init(center: UNUserNotificationCenter = .current(), defaults: UserDefaults = .standard) {
        self.center = center
        self.defaults = defaults
    }

    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func evaluate(_ snapshots: [ProviderSnapshot], settings: AppSettings) async {
        guard settings.alertsEnabled else { return }
        var history = (defaults.dictionary(forKey: historyKey) as? [String: TimeInterval]) ?? [:]
        for window in snapshots.flatMap(\.windows) {
            let threshold = settings.threshold(for: window)
            let cycle = window.resetsAt?.timeIntervalSince1970 ?? 0
            if window.remainingPercent <= threshold, history[window.id] != cycle {
                let content = UNMutableNotificationContent()
                content.title = "\(window.provider.displayName) usage is low"
                content.body = "\(Int(window.remainingPercent.rounded()))% remains for \(window.displayName)."
                content.sound = .default
                try? await center.add(UNNotificationRequest(
                    identifier: "vibemeter.\(window.id).\(Int(cycle))",
                    content: content,
                    trigger: nil
                ))
                history[window.id] = cycle
            } else if window.remainingPercent > threshold {
                history.removeValue(forKey: window.id)
            }
        }
        defaults.set(history, forKey: historyKey)
    }
}
