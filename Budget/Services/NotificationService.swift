import Foundation
import UserNotifications
import UIKit

@MainActor
class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()

    @Published var isAuthorized = false
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    // Notification identifiers
    private enum NotificationIdentifier {
        static let dailyExpenseReminder = "daily_expense_reminder"
        static let budgetAlert = "budget_alert"
        static let weeklyReview = "weekly_review"
        static let budgetEndingSoon = "budget_ending_soon"
        static let budgetExpired = "budget_expired"

        static func budgetAlert(for categoryId: UUID) -> String {
            return "budget_alert_\(categoryId.uuidString)"
        }
    }

    override init() {
        super.init()
        checkAuthorizationStatus()
    }

    // MARK: - Authorization

    func requestNotificationPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(
                options: [.alert, .sound, .badge]
            )

            await MainActor.run {
                isAuthorized = granted
                if granted {
                    authorizationStatus = .authorized
                } else {
                    authorizationStatus = .denied
                }
            }

            return granted
        } catch {
            print("Notification permission error: \(error)")
            await MainActor.run {
                isAuthorized = false
                authorizationStatus = .denied
            }
            return false
        }
    }

    private func checkAuthorizationStatus() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    // MARK: - Daily Expense Reminders

    func scheduleDailyExpenseReminder(
        at hour: Int = 19, // 7 PM default
        minute: Int = 0,
        isEnabled: Bool = true
    ) {
        guard isAuthorized else { return }

        let center = UNUserNotificationCenter.current()

        // Remove existing reminder
        center.removePendingNotificationRequests(
            withIdentifiers: [NotificationIdentifier.dailyExpenseReminder]
        )

        guard isEnabled else { return }

        // Create new reminder
        let content = UNMutableNotificationContent()
        content.title = "Track Your Expenses"
        content.body = dailyReminderMessage()
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = "DAILY_REMINDER"

        // Set up date components for daily repeat
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: NotificationIdentifier.dailyExpenseReminder,
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error = error {
                print("Failed to schedule daily reminder: \(error)")
            }
        }
    }

    private func dailyReminderMessage() -> String {
        let messages = [
            "Don't forget to log today's expenses! 💰",
            "Keep your budget on track - add today's purchases 📝",
            "A few minutes to update your expenses can save you hundreds! ✨",
            "Your future self will thank you for tracking today's spending 🙏",
            "Stay in control - log your expenses now! 🎯"
        ]
        return messages.randomElement() ?? messages[0]
    }

    // MARK: - Budget Threshold Alerts

    func scheduleBudgetAlert(
        for category: SubCategory,
        currentAmount: Double,
        budgetAmount: Double,
        threshold: Double // 0.75 for 75%, 0.90 for 90%, 1.0 for 100%
    ) {
        guard isAuthorized, budgetAmount > 0 else { return }

        let utilization = currentAmount / budgetAmount
        guard utilization >= threshold else { return }

        let center = UNUserNotificationCenter.current()
        let identifier = NotificationIdentifier.budgetAlert(for: category.id)

        // Remove existing alert for this category
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.sound = threshold >= 1.0 ? .defaultCritical : .default
        content.badge = 1
        content.categoryIdentifier = "BUDGET_ALERT"

        let percentage = Int(utilization * 100)

        if threshold >= 1.0 {
            // Over budget
            content.title = "Budget Exceeded! 🚨"
            content.body = "You've spent \(String(format: "%.0f", currentAmount)) on \(category.name), which is \(percentage - 100)% over your \(String(format: "%.0f", budgetAmount)) budget."
        } else if threshold >= 0.9 {
            // 90% threshold
            content.title = "Budget Alert! ⚠️"
            content.body = "You've used \(percentage)% of your \(category.name) budget (\(String(format: "%.0f", currentAmount))/\(String(format: "%.0f", budgetAmount)))"
        } else {
            // 75% threshold
            content.title = "Budget Warning 💡"
            content.body = "You're at \(percentage)% of your \(category.name) budget. \(String(format: "%.0f", budgetAmount - currentAmount)) remaining."
        }

        // Schedule for immediate delivery
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error = error {
                print("Failed to schedule budget alert: \(error)")
            }
        }
    }

    // MARK: - Weekly Review Notifications

    func scheduleWeeklyReview(
        on weekday: Int = 1, // Sunday = 1
        at hour: Int = 10, // 10 AM
        minute: Int = 0,
        isEnabled: Bool = true
    ) {
        guard isAuthorized else { return }

        let center = UNUserNotificationCenter.current()

        // Remove existing weekly review
        center.removePendingNotificationRequests(
            withIdentifiers: [NotificationIdentifier.weeklyReview]
        )

        guard isEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Weekly Budget Review 📊"
        content.body = "Take a moment to review this week's spending and plan ahead!"
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = "WEEKLY_REVIEW"

        var dateComponents = DateComponents()
        dateComponents.weekday = weekday
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: NotificationIdentifier.weeklyReview,
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error = error {
                print("Failed to schedule weekly review: \(error)")
            }
        }
    }

    // MARK: - Smart Reminder Logic

    func shouldSkipDailyReminder(basedOnRecentActivity transactions: [Transaction]) -> Bool {
        let calendar = Calendar.current
        let today = Date()

        // Skip if user has added transactions today
        let todayTransactions = transactions.filter { transaction in
            calendar.isDate(transaction.date, inSameDayAs: today)
        }

        return !todayTransactions.isEmpty
    }

    func scheduleSmartDailyReminder(
        basedOnTransactions transactions: [Transaction],
        at hour: Int = 19,
        minute: Int = 0
    ) {
        // Skip if user has been active today
        if shouldSkipDailyReminder(basedOnRecentActivity: transactions) {
            return
        }

        scheduleDailyExpenseReminder(at: hour, minute: minute, isEnabled: true)
    }

    // MARK: - Notification Management

    func clearAllNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()

        // Reset badge count
        UIApplication.shared.applicationIconBadgeNumber = 0
    }

    func clearNotification(withIdentifier identifier: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    func getPendingNotifications() async -> [UNNotificationRequest] {
        let center = UNUserNotificationCenter.current()
        return await center.pendingNotificationRequests()
    }

    func getDeliveredNotifications() async -> [UNNotification] {
        let center = UNUserNotificationCenter.current()
        return await center.deliveredNotifications()
    }

    // MARK: - Budget End Notifications

    func scheduleBudgetEndNotifications(for budget: Budget) {
        guard isAuthorized else { return }

        let center = UNUserNotificationCenter.current()

        // Clear any existing budget end notifications
        center.removePendingNotificationRequests(withIdentifiers: [
            NotificationIdentifier.budgetEndingSoon,
            NotificationIdentifier.budgetExpired
        ])

        // Schedule "ending soon" notification (1 day before end)
        let endDate = budget.period.endDate
        let oneDayBefore = Calendar.current.date(byAdding: .day, value: -1, to: endDate)

        if let reminderDate = oneDayBefore, reminderDate > Date() {
            scheduleBudgetEndingSoonNotification(for: budget, at: reminderDate)
        }

        // Schedule "expired" notification (1 day after end)
        let oneDayAfter = Calendar.current.date(byAdding: .day, value: 1, to: endDate)

        if let expiredDate = oneDayAfter {
            scheduleBudgetExpiredNotification(for: budget, at: expiredDate)
        }
    }

    private func scheduleBudgetEndingSoonNotification(for budget: Budget, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Budget Ending Soon! ⏰"
        content.body = "Your \(budget.budgetName) ends tomorrow (\(formatDate(budget.period.endDate))). Plan your next budget!"
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = "BUDGET_ENDING"

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(
            identifier: NotificationIdentifier.budgetEndingSoon,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule budget ending notification: \(error)")
            }
        }
    }

    private func scheduleBudgetExpiredNotification(for budget: Budget, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Budget Expired! 📊"
        content.body = "Your \(budget.budgetName) ended on \(formatDate(budget.period.endDate)). Create your next budget now!"
        content.sound = .defaultCritical
        content.badge = 1
        content.categoryIdentifier = "BUDGET_EXPIRED"

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(
            identifier: NotificationIdentifier.budgetExpired,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule budget expired notification: \(error)")
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    // MARK: - Background App Refresh Support

    func scheduleBackgroundNotificationCheck() {
        // This would be called when the app enters background
        // to schedule a local notification check

        let identifier = "background_check"
        let content = UNMutableNotificationContent()
        content.title = "Budget Check"
        content.body = "Checking your budget status..."
        content.sound = nil // Silent
        content.badge = 0

        // Check after 1 hour in background
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false)

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notifications even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Handle notification tap
        let identifier = response.notification.request.identifier

        // Post notification for the app to handle
        NotificationCenter.default.post(
            name: NSNotification.Name("NotificationTapped"),
            object: identifier
        )

        completionHandler()
    }
}

// MARK: - Notification Settings Model
struct NotificationSettings: Codable {
    var dailyRemindersEnabled: Bool = true
    var dailyReminderTime: Date = {
        var components = DateComponents()
        components.hour = 19 // 7 PM
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }()

    var budgetAlertsEnabled: Bool = true
    var weeklyReviewEnabled: Bool = true
    var weeklyReviewDay: Int = 1 // Sunday
    var weeklyReviewTime: Date = {
        var components = DateComponents()
        components.hour = 10 // 10 AM
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }()

}

// MARK: - UserDefaults Extension for Settings
extension UserDefaults {
    private enum Keys {
        static let notificationSettings = "notification_settings"
    }

    var notificationSettings: NotificationSettings {
        get {
            if let data = data(forKey: Keys.notificationSettings),
               let settings = try? JSONDecoder().decode(NotificationSettings.self, from: data) {
                return settings
            }
            return NotificationSettings()
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                set(data, forKey: Keys.notificationSettings)
            }
        }
    }
}