import Foundation
import SwiftUI

@MainActor
@Observable
class NotificationManager {
    private var workItem: DispatchWorkItem?
    
    var isVisible = false
    var message = ""
    var type: DSSnackbar.SnackbarType = .info
    var actionTitle: String?
    var onAction: (() -> Void)?
    
    func show(_ message: String, type: DSSnackbar.SnackbarType = .info, duration: TimeInterval = 3.0, actionTitle: String? = nil, onAction: (() -> Void)? = nil) {
        // Cancel any existing work item
        workItem?.cancel()

        // Update the notification properties
        self.message = message
        self.type = type
        self.actionTitle = actionTitle
        self.onAction = onAction

        // Show with animation
        withAnimation(.easeInOut(duration: 0.3)) {
            isVisible = true
        }

        // Create new work item to dismiss after duration
        workItem = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.isVisible = false
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem!)
    }
    
    func dismiss() {
        workItem?.cancel()
        withAnimation(.easeInOut(duration: 0.3)) {
            isVisible = false
        }
        // Clear action properties
        actionTitle = nil
        onAction = nil
    }

    func showSuccess(_ message: String) {
        show(message, type: .success)
    }

    func showError(_ message: String) {
        show(message, type: .error)
    }

    func showInfo(_ message: String) {
        show(message, type: .info)
    }

    func showUndo(_ message: String, onUndo: @escaping () -> Void) {
        show(message, type: .undo, duration: 5.0, actionTitle: "Undo", onAction: onUndo)
    }
}