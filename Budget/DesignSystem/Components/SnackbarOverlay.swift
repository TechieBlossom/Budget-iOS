import SwiftUI

struct SnackbarOverlay: ViewModifier {
    @Bindable var notificationManager: NotificationManager
    
    func body(content: Content) -> some View {
        content
            .overlay(
                VStack {
                    if notificationManager.isVisible {
                        DSSnackbar(
                            message: notificationManager.message,
                            type: notificationManager.type,
                            onDismiss: {
                                notificationManager.dismiss()
                            },
                            actionTitle: notificationManager.actionTitle,
                            onAction: notificationManager.onAction
                        )
                        .padding(.horizontal, DSSpacing.md)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    Spacer()
                },
                alignment: .top
            )
    }
}

extension View {
    func snackbar(_ notificationManager: NotificationManager) -> some View {
        modifier(SnackbarOverlay(notificationManager: notificationManager))
    }
}