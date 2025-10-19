import Foundation
import UIKit

@MainActor
class HapticManager {
    static let shared = HapticManager()

    private init() {}

    // MARK: - Impact Feedback

    func lightImpact() {
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.impactOccurred()
    }

    func mediumImpact() {
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.impactOccurred()
    }

    func heavyImpact() {
        let feedback = UIImpactFeedbackGenerator(style: .heavy)
        feedback.impactOccurred()
    }

    // MARK: - Notification Feedback

    func success() {
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
    }

    func error() {
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.error)
    }

    func warning() {
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.warning)
    }

    // MARK: - Selection Feedback

    func selection() {
        let feedback = UISelectionFeedbackGenerator()
        feedback.selectionChanged()
    }

    // MARK: - Context-Specific Haptics

    func buttonTap() {
        lightImpact()
    }

    func transactionAdded() {
        success()
    }

    func transactionDeleted() {
        mediumImpact()
    }

    func transactionRestored() {
        success()
    }

    func categorySelected() {
        selection()
    }

    func filterApplied() {
        lightImpact()
    }

    func searchTextChanged() {
        // Very subtle feedback for typing
        // Note: In practice, this might be too frequent and should be used sparingly
    }

    func navigationBack() {
        lightImpact()
    }

    func operationFailed() {
        error()
    }

    func longPress() {
        mediumImpact()
    }

    func swipeAction() {
        lightImpact()
    }
}