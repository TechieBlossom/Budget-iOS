import SwiftUI

struct DSSnackbar: View {
    enum SnackbarType {
        case success
        case error
        case info
        case undo

        var iconName: String {
            switch self {
            case .success:
                return "checkmark.circle.fill"
            case .error:
                return "exclamationmark.circle.fill"
            case .info:
                return "info.circle.fill"
            case .undo:
                return "arrow.uturn.backward.circle.fill"
            }
        }

        var iconColor: Color {
            switch self {
            case .success:
                return .green
            case .error:
                return .red
            case .info:
                return .blue
            case .undo:
                return .orange
            }
        }
    }

    let message: String
    let type: SnackbarType
    let onDismiss: () -> Void
    let actionTitle: String?
    let onAction: (() -> Void)?
    
    @Environment(\.appTheme) private var theme
    
    init(message: String, type: SnackbarType, onDismiss: @escaping () -> Void, actionTitle: String? = nil, onAction: (() -> Void)? = nil) {
        self.message = message
        self.type = type
        self.onDismiss = onDismiss
        self.actionTitle = actionTitle
        self.onAction = onAction
    }

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: type.iconName)
                .foregroundColor(type.iconColor)
                .font(.dsHeadline)

            DSText(message, font: .dsBody, color: theme.colors.textPrimary)
                .lineLimit(2)

            Spacer()

            // Action button (e.g., Undo)
            if let actionTitle = actionTitle, let onAction = onAction {
                Button(action: {
                    onAction()
                    onDismiss()
                }) {
                    DSText(actionTitle, font: .dsCaption, color: theme.colors.textPrimary)
                        .fontWeight(.medium)
                        .padding(.horizontal, DSSpacing.xs)
                        .padding(.vertical, DSSpacing.xxs)
                        .background(theme.colors.textPrimary.opacity(0.1))
                        .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(theme.colors.textSecondary)
                    .font(.dsCaption)
                    .fontWeight(.medium)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, DSSpacing.md)
        .padding(.vertical, DSSpacing.sm)
        .background(theme.colors.surface)
        .cornerRadius(8)
        .shadow(color: theme.colors.textPrimary.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    VStack(spacing: DSSpacing.md) {
        DSSnackbar(message: "Transaction added successfully!", type: .success, onDismiss: {})
        DSSnackbar(message: "Failed to update transaction", type: .error, onDismiss: {})
        DSSnackbar(message: "Budget updated", type: .info, onDismiss: {})
        DSSnackbar(message: "Transaction deleted", type: .undo, onDismiss: {}, actionTitle: "Undo", onAction: {})
    }
    .padding(DSSpacing.md)
    .background(AppTheme.shared.colors.background)
}