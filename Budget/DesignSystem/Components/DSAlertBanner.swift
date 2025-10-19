import SwiftUI

// MARK: - Alert Banner Types
enum DSAlertBannerType {
    case budgetWarning
    case budgetAlert
    case budgetExceeded
    case info
    case success
    case error

    var backgroundColor: Color {
        switch self {
        case .budgetWarning:
            return .orange.opacity(0.1)
        case .budgetAlert:
            return .red.opacity(0.1)
        case .budgetExceeded:
            return .red.opacity(0.15)
        case .info:
            return .blue.opacity(0.1)
        case .success:
            return .green.opacity(0.1)
        case .error:
            return .red.opacity(0.1)
        }
    }

    var borderColor: Color {
        switch self {
        case .budgetWarning:
            return .orange.opacity(0.3)
        case .budgetAlert:
            return .red.opacity(0.3)
        case .budgetExceeded:
            return .red.opacity(0.5)
        case .info:
            return .blue.opacity(0.3)
        case .success:
            return .green.opacity(0.3)
        case .error:
            return .red.opacity(0.3)
        }
    }

    var iconName: String {
        switch self {
        case .budgetWarning:
            return "exclamationmark.triangle.fill"
        case .budgetAlert:
            return "exclamationmark.circle.fill"
        case .budgetExceeded:
            return "xmark.circle.fill"
        case .info:
            return "info.circle.fill"
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "xmark.circle.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .budgetWarning:
            return .orange
        case .budgetAlert, .budgetExceeded, .error:
            return .red
        case .info:
            return .blue
        case .success:
            return .green
        }
    }
}

// MARK: - Alert Banner Data
struct DSAlertBannerData: Identifiable, Equatable {
    let id = UUID()
    let type: DSAlertBannerType
    let title: String
    let message: String
    let actionTitle: String?
    let onAction: (() -> Void)?
    let onDismiss: (() -> Void)?
    let autoDismissAfter: TimeInterval?

    init(
        type: DSAlertBannerType,
        title: String,
        message: String,
        actionTitle: String? = nil,
        onAction: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil,
        autoDismissAfter: TimeInterval? = nil
    ) {
        self.type = type
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.onAction = onAction
        self.onDismiss = onDismiss
        self.autoDismissAfter = autoDismissAfter
    }

    static func == (lhs: DSAlertBannerData, rhs: DSAlertBannerData) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Factory Methods for Budget Alerts

    static func budgetWarning(
        category: SubCategory,
        percentage: Double,
        onReviewBudget: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) -> DSAlertBannerData {
        DSAlertBannerData(
            type: .budgetWarning,
            title: "\(category.name) Budget Alert",
            message: "You've used \(String(format: "%.0f", percentage))% of your budget",
            actionTitle: "Review",
            onAction: onReviewBudget,
            onDismiss: onDismiss,
            autoDismissAfter: 8.0
        )
    }

    static func budgetAlert(
        category: SubCategory,
        percentage: Double,
        onAdjustBudget: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) -> DSAlertBannerData {
        DSAlertBannerData(
            type: .budgetAlert,
            title: "\(category.name) Budget Alert!",
            message: "You've used \(String(format: "%.0f", percentage))% of your budget",
            actionTitle: "Adjust Budget",
            onAction: onAdjustBudget,
            onDismiss: onDismiss,
            autoDismissAfter: 10.0
        )
    }

    static func budgetExceeded(
        category: SubCategory,
        amount: Double,
        budgetAmount: Double,
        onAdjustBudget: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) -> DSAlertBannerData {
        let overAmount = amount - budgetAmount
        return DSAlertBannerData(
            type: .budgetExceeded,
            title: "Budget Exceeded!",
            message: "\(category.name) is \(String(format: "%.0f", overAmount)) over budget",
            actionTitle: "Adjust Budget",
            onAction: onAdjustBudget,
            onDismiss: onDismiss
        )
    }

    static func transactionAddedNearLimit(
        category: SubCategory,
        newPercentage: Double,
        onViewCategory: @escaping () -> Void
    ) -> DSAlertBannerData {
        DSAlertBannerData(
            type: .budgetAlert,
            title: "Transaction Added",
            message: "\(category.name) is now at \(String(format: "%.0f", newPercentage))% of budget",
            actionTitle: "View Category",
            onAction: onViewCategory,
            onDismiss: nil,
            autoDismissAfter: 6.0
        )
    }
}

// MARK: - Main Alert Banner Component
struct DSAlertBanner: View {
    let data: DSAlertBannerData
    @State private var isVisible = false
    @State private var dragOffset: CGSize = .zero
    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            // Icon
            Image(systemName: data.type.iconName)
                .font(.dsHeadline)
                .fontWeight(.medium)
                .foregroundColor(data.type.iconColor)
                .frame(width: 20, height: 20)

            // Content
            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                DSText(
                    data.title,
                    font: .dsBody,
                    color: theme.colors.textPrimary
                )
                .fontWeight(.semibold)

                DSText(
                    data.message,
                    font: .dsCaption,
                    color: theme.colors.textSecondary
                )
                .lineLimit(2)
            }

            Spacer()

            // Action button
            if let actionTitle = data.actionTitle {
                DSButton(actionTitle, style: .outline) {
                    HapticManager.shared.buttonTap()
                    data.onAction?()
                }
            }

            // Dismiss button
            Button(action: {
                HapticManager.shared.lightImpact()
                dismissWithAnimation()
            }) {
                Image(systemName: "xmark")
                    .font(.dsCaption)
                    .fontWeight(.medium)
                    .foregroundColor(theme.colors.textSecondary)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, DSSpacing.md)
        .padding(.vertical, DSSpacing.sm)
        .background(data.type.backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(data.type.borderColor, lineWidth: 1)
        )
        .cornerRadius(12)
        .offset(y: dragOffset.height)
        .offset(y: isVisible ? 0 : -100)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.95)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height < 0 {
                        dragOffset = value.translation
                    }
                }
                .onEnded { value in
                    if value.translation.height < -50 {
                        dismissWithAnimation()
                    } else {
                        withAnimation(.bouncy) {
                            dragOffset = .zero
                        }
                    }
                }
        )
        .onAppear {
            showWithAnimation()

            // Auto-dismiss if specified
            if let autoDismissAfter = data.autoDismissAfter {
                DispatchQueue.main.asyncAfter(deadline: .now() + autoDismissAfter) {
                    dismissWithAnimation()
                }
            }
        }
    }

    private func showWithAnimation() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            isVisible = true
        }
    }

    private func dismissWithAnimation() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isVisible = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            data.onDismiss?()
        }
    }
}

// MARK: - Alert Banner Manager
@MainActor
class DSAlertBannerManager: ObservableObject {
    @Published var currentAlert: DSAlertBannerData?
    @Published var alertQueue: [DSAlertBannerData] = []

    private var alertTimer: Timer?

    func showAlert(_ alert: DSAlertBannerData) {
        // Cancel any existing timer
        alertTimer?.invalidate()

        if currentAlert == nil {
            // Show immediately
            currentAlert = alert
        } else {
            // Add to queue
            alertQueue.append(alert)
        }

        // Set up auto-dismiss timer
        if let autoDismissAfter = alert.autoDismissAfter {
            alertTimer = Timer.scheduledTimer(withTimeInterval: autoDismissAfter, repeats: false) { _ in
                self.dismissCurrentAlert()
            }
        }
    }

    func dismissCurrentAlert() {
        alertTimer?.invalidate()
        currentAlert = nil

        // Show next alert in queue
        if !alertQueue.isEmpty {
            let nextAlert = alertQueue.removeFirst()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showAlert(nextAlert)
            }
        }
    }

    func clearAllAlerts() {
        alertTimer?.invalidate()
        currentAlert = nil
        alertQueue.removeAll()
    }

    // MARK: - Budget-specific helper methods

    func showBudgetAlert(
        for category: SubCategory,
        currentAmount: Double,
        budgetAmount: Double,
        onAdjustBudget: @escaping () -> Void,
        onReviewCategory: @escaping () -> Void
    ) {
        let percentage = (currentAmount / budgetAmount) * 100

        let alert: DSAlertBannerData

        if percentage >= 100 {
            alert = .budgetExceeded(
                category: category,
                amount: currentAmount,
                budgetAmount: budgetAmount,
                onAdjustBudget: onAdjustBudget,
                onDismiss: dismissCurrentAlert
            )
        } else if percentage >= 90 {
            alert = .budgetAlert(
                category: category,
                percentage: percentage,
                onAdjustBudget: onAdjustBudget,
                onDismiss: dismissCurrentAlert
            )
        } else if percentage >= 75 {
            alert = .budgetWarning(
                category: category,
                percentage: percentage,
                onReviewBudget: onReviewCategory,
                onDismiss: dismissCurrentAlert
            )
        } else {
            return // No alert needed
        }

        showAlert(alert)
    }

    func showTransactionAlert(
        for category: SubCategory,
        newPercentage: Double,
        onViewCategory: @escaping () -> Void
    ) {
        guard newPercentage >= 75 else { return }

        let alert = DSAlertBannerData.transactionAddedNearLimit(
            category: category,
            newPercentage: newPercentage,
            onViewCategory: onViewCategory
        )

        showAlert(alert)
    }
}

// MARK: - Alert Banner Container
struct DSAlertBannerContainer: View {
    @StateObject private var alertManager = DSAlertBannerManager()
    let content: AnyView

    init<Content: View>(@ViewBuilder content: () -> Content) {
        self.content = AnyView(content())
    }

    var body: some View {
        ZStack(alignment: .top) {
            content

            if let currentAlert = alertManager.currentAlert {
                VStack {
                    DSAlertBanner(data: currentAlert)
                        .padding(.horizontal, DSSpacing.md)
                        .padding(.top, DSSpacing.xs)

                    Spacer()
                }
                .zIndex(1000)
            }
        }
        .environmentObject(alertManager)
    }
}

// MARK: - View Extension for Easy Usage
extension View {
    func alertBanner() -> some View {
        DSAlertBannerContainer {
            self
        }
    }
}

#Preview {
    let sampleCategory = SubCategory(name: "Groceries", categoryGroup: .essentials)

    VStack(spacing: DSSpacing.lg) {
        DSAlertBanner(
            data: .budgetWarning(
                category: sampleCategory,
                percentage: 78,
                onReviewBudget: { print("Review budget tapped") },
                onDismiss: { print("Dismissed warning") }
            )
        )

        DSAlertBanner(
            data: .budgetAlert(
                category: sampleCategory,
                percentage: 95,
                onAdjustBudget: { print("Adjust budget tapped") },
                onDismiss: { print("Dismissed alert") }
            )
        )

        DSAlertBanner(
            data: .budgetExceeded(
                category: sampleCategory,
                amount: 550,
                budgetAmount: 500,
                onAdjustBudget: { print("Adjust budget tapped") },
                onDismiss: { print("Dismissed exceeded") }
            )
        )
    }
    .padding(DSSpacing.md)
    .background(AppTheme.shared.colors.background)
}