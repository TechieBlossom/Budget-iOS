import SwiftUI

/// Reusable budget period/date management UI component for onboarding and settings
struct DSBudgetPeriodManagementView: View {
    // MARK: - Properties
    @Binding var budgetName: String
    @Binding var startDate: Date
    @Binding var endDate: Date?
    @Binding var budgetType: BudgetType

    let showHeader: Bool
    let headerTitle: String?
    let headerSubtitle: String?
    let onBack: (() -> Void)?

    @Environment(\.appTheme) private var theme

    // MARK: - Initializers

    init(
        budgetName: Binding<String>,
        startDate: Binding<Date>,
        endDate: Binding<Date?>,
        budgetType: Binding<BudgetType>,
        showHeader: Bool = false,
        headerTitle: String? = nil,
        headerSubtitle: String? = nil,
        onBack: (() -> Void)? = nil
    ) {
        self._budgetName = budgetName
        self._startDate = startDate
        self._endDate = endDate
        self._budgetType = budgetType
        self.showHeader = showHeader
        self.headerTitle = headerTitle
        self.headerSubtitle = headerSubtitle
        self.onBack = onBack
    }

    // MARK: - Computed Properties

    private var autoCalculatedEndDate: Date {
        let calendar = Calendar.current
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        let calculatedEndDate = calendar.date(byAdding: .day, value: -1, to: nextMonth) ?? startDate
        return calculatedEndDate
    }

    private var maxEndDate: Date {
        Calendar.current.date(byAdding: .day, value: 31, to: startDate) ?? startDate
    }

    private var minEndDate: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: startDate) ?? startDate
    }

    private var suggestedBudgetName: String {
        if let endDateValue = endDate {
            return BudgetPeriod.generateCustomName(for: startDate, endDate: endDateValue)
        }
        return "Custom Budget"
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Optional Header (for onboarding flow)
            if showHeader, let title = headerTitle, let subtitle = headerSubtitle, let backAction = onBack {
                DSHeader(
                    title: title,
                    subtitle: subtitle,
                    buttonType: .back,
                    onBack: backAction
                )
            }

            // Scrollable Content
            ScrollView {
                VStack(spacing: DSSpacing.md) {
                    // Budget Name Field
                    VStack(alignment: .leading, spacing: DSSpacing.xs) {
                        DSText("Budget Name", font: .dsHeadline, color: theme.colors.textPrimary)
                        DSTextField("e.g., Monthly Budget, Vacation Fund", text: $budgetName, autocapitalization: .words)
                    }
                    .padding(.horizontal, DSSpacing.md)
                    .padding(.bottom, DSSpacing.md)
                    
                    HStack(spacing: DSSpacing.xs) {
                        DSText("Budget Duration", font: .dsHeadline, color: theme.colors.textPrimary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, DSSpacing.md)

                    // Start Date Picker
                    DSCard {
                        HStack(spacing: DSSpacing.md) {
                            DSText("Start Date", font: .dsBody, color: theme.colors.textPrimary)

                            Spacer()

                            DatePicker("", selection: $startDate, in: ...Date(), displayedComponents: [.date])
                                .labelsHidden()
                                .tint(theme.colors.primary)
                                .onChange(of: startDate) { oldValue, newValue in
                                    autoUpdateEndDate()
                                    updateBudgetName()
                                }
                        }
                    }
                    .padding(.horizontal, DSSpacing.md)

                    // End Date Picker
                    DSCard {
                        HStack(spacing: DSSpacing.md) {
                            DSText("End Date", font: .dsBody, color: theme.colors.textPrimary)

                            Spacer()

                            DatePicker("", selection: Binding(
                                get: { endDate ?? autoCalculatedEndDate },
                                set: { newValue in
                                    if newValue > startDate {
                                        if newValue <= maxEndDate {
                                            endDate = newValue
                                            updateBudgetType()
                                        } else {
                                            endDate = maxEndDate
                                            budgetType = .custom
                                        }
                                    } else {
                                        endDate = minEndDate
                                        budgetType = .custom
                                    }
                                    updateBudgetName()
                                }
                            ), in: minEndDate...maxEndDate, displayedComponents: [.date])
                                .labelsHidden()
                                .tint(theme.colors.primary)
                        }
                    }
                    .padding(.horizontal, DSSpacing.md)

                    // Info message about 31-day limit
                    HStack(spacing: DSSpacing.xs) {
                        Image(systemName: "info.circle")
                            .font(.dsSubtitle)
                            .foregroundColor(theme.colors.textSecondary)
                        VStack(alignment: .leading, spacing: 2) {
                            DSText("Budget duration is limited to a maximum of 31 days.", font: .dsCaption, color: theme.colors.textSecondary)
                            DSText("Longer periods help maintain better spending control.", font: .dsCaption, color: theme.colors.textSecondary)
                        }

                        Spacer()
                    }
                    .padding(.top, DSSpacing.xxs)
                    .padding(.horizontal, DSSpacing.md)
                }
            }
        }
        .padding(.top, DSSpacing.md)
        .background(theme.colors.background)
        .animation(.easeInOut(duration: 0.3), value: budgetType)
        .onAppear {
            initializeState()
        }
    }

    // MARK: - Helper Methods

    private func initializeState() {
        if endDate == nil {
            endDate = autoCalculatedEndDate
            budgetType = .monthly
        }

        if budgetName.isEmpty {
            budgetName = suggestedBudgetName
        }
    }

    private func autoUpdateEndDate() {
        endDate = autoCalculatedEndDate
        budgetType = .monthly
    }

    private func updateBudgetType() {
        if let endDateValue = endDate {
            let calendar = Calendar.current
            let calculatedEndDate = autoCalculatedEndDate

            if calendar.isDate(endDateValue, inSameDayAs: calculatedEndDate) {
                budgetType = .monthly
            } else {
                budgetType = .custom
            }
        }
    }

    private func updateBudgetName() {
        if shouldAutoUpdateName() {
            budgetName = suggestedBudgetName
        }
    }

    private func shouldAutoUpdateName() -> Bool {
        return budgetName.isEmpty ||
               budgetName.contains("Budget") ||
               budgetName.contains(",") ||
               budgetName.contains("-")
    }
}

#Preview("Onboarding Style") {
    @Previewable @State var budgetName = ""
    @Previewable @State var startDate = Date()
    @Previewable @State var endDate: Date? = nil
    @Previewable @State var budgetType: BudgetType = .monthly

    return DSBudgetPeriodManagementView(
        budgetName: $budgetName,
        startDate: $startDate,
        endDate: $endDate,
        budgetType: $budgetType,
        showHeader: true,
        headerTitle: "Dates",
        headerSubtitle: "Set start and end dates for budget period",
        onBack: {}
    )
}

#Preview("Settings Style") {
    @Previewable @State var budgetName = "January 2025 Budget"
    @Previewable @State var startDate = Date()
    @Previewable @State var endDate: Date? = Date()
    @Previewable @State var budgetType: BudgetType = .monthly

    return DSBudgetPeriodManagementView(
        budgetName: $budgetName,
        startDate: $startDate,
        endDate: $endDate,
        budgetType: $budgetType,
        showHeader: false
    )
}
