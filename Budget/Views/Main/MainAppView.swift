//
//  MainAppView.swift
//  Budget
//
//  Created by Prateek Sharma on 05/09/2025.
//

import SwiftUI

enum MainTab {
    case budget
    case analysis
    case settings
    case add
}

struct MainAppView: View {
    let budgetManager: BudgetManager
    @Binding var showingBudgetSettings: Bool
    @Environment(\.appTheme) private var theme
    @State private var selectedTab: MainTab = .budget
    @State private var expandedGroups: Set<CategoryGroup> = []
    @State private var showingAddTransaction = false
    @State private var transactionToEdit: Transaction?
    @State private var showingEndBudgetConfirmation = false
    @State private var notificationManager = NotificationManager()
    @State private var expensesOnlyMode = false  // User controls visibility via category group filter
    @StateObject private var categoryGroupPreferences = CategoryGroupPreferences()
    @State private var showingCategoryGroupFilter = false
    @State private var showingCurrencySettings = false
    @State private var showingPeriodSettings = false
    @State private var showingCategorySettings = false
    @State private var selectedCategory: SubCategory?
    @State private var showingAllTransactions = false
    @State private var showingHistoricalBudgets = false
    @State private var showingSignOutConfirmation = false
    @State private var showingAddCategory = false
    @State private var preSelectedCategoryGroup: CategoryGroup?
    @Environment(AuthManager.self) private var authManager

    init(budgetManager: BudgetManager, showingBudgetSettings: Binding<Bool>) {
        self.budgetManager = budgetManager
        self._showingBudgetSettings = showingBudgetSettings
    }

    private var sortedCategoryGroups: [CategoryGroup] {
        // Get groups that have sub-categories with budgets (respect expenses-only mode and selected groups)
        let groupsWithBudget = CategoryGroup.allCases.filter { group in
            let allocated = budgetManager.allocatedAmount(for: group, excludingSavings: expensesOnlyMode)
            let isSelected = categoryGroupPreferences.selectedGroups.contains(group)
            return allocated > 0 && isSelected
        }

        // Sort by spending percentage (highest first)
        return groupsWithBudget.sorted { group1, group2 in
            let percentage1 = budgetManager.spentPercentage(for: group1, excludingSavings: expensesOnlyMode)
            let percentage2 = budgetManager.spentPercentage(for: group2, excludingSavings: expensesOnlyMode)
            return percentage1 > percentage2
        }
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                Tab("Budget", systemImage: "dollarsign.circle", value: .budget) {
                    budgetTabContent
                }

                Tab("Analysis", systemImage: "chart.bar", value: .analysis) {
                    analysisTabContent
                }

                Tab("Settings", systemImage: "gearshape", value: .settings) {
                    settingsTabContent
                }

                Tab("Add", systemImage: "plus.circle", value: .add, role: .search) {

                }
            }
            .tint(theme.colors.primary)
            .background(theme.colors.background)
            .customNavigationBarAppearance()
            .onChange(of: selectedTab) { oldValue, newValue in
                // Intercept add tab tap and show transaction sheet
                if newValue == .add {
                    HapticManager.shared.buttonTap()
                    showingAddTransaction = true
                    // Revert to previous tab so user stays where they were
                    selectedTab = oldValue
                }
            }
            .navigationBarBackButtonHidden(false)
            .snackbar(notificationManager)
            .fullScreenCover(isPresented: $showingAddTransaction) {
                AddTransactionSheet(
                    budgetId: budgetManager.budget.id,
                    categories: budgetManager.budget.categories,
                    currency: budgetManager.budget.currency,
                    budgetPeriod: budgetManager.budget.period,
                    budgetName: budgetManager.budget.budgetName,
                    categoryAmounts: budgetManager.budget.categoryAmounts,
                    existingTransaction: nil,
                    budgetManager: budgetManager,
                    onSuccess: {
                        HapticManager.shared.transactionAdded()
                        notificationManager.showSuccess("Transaction added successfully!")
                        showingAddTransaction = false
                    }
                )
            }
            .fullScreenCover(item: $transactionToEdit) { transaction in
                AddTransactionSheet(
                    budgetId: budgetManager.budget.id,
                    categories: budgetManager.budget.categories,
                    currency: budgetManager.budget.currency,
                    budgetPeriod: budgetManager.budget.period,
                    budgetName: budgetManager.budget.budgetName,
                    categoryAmounts: budgetManager.budget.categoryAmounts,
                    existingTransaction: transaction,
                    budgetManager: budgetManager,
                    onSuccess: {
                        HapticManager.shared.success()
                        notificationManager.showSuccess("Transaction updated successfully!")
                        transactionToEdit = nil
                    }
                )
            }
            .navigationDestination(item: $selectedCategory) { category in
                CategoryDetailView(category: category, budgetManager: budgetManager)
            }
            .navigationDestination(isPresented: $showingAllTransactions) {
                AllTransactionsView(budgetManager: budgetManager)
            }
            .sheet(isPresented: $showingCategoryGroupFilter) {
                DSCategoryGroupFilterSheet(preferences: categoryGroupPreferences)
                    .presentationDetents([.medium, .large])
            }
            .navigationDestination(isPresented: $showingHistoricalBudgets) {
                HistoricalBudgetsView()
            }
            .fullScreenCover(isPresented: $showingEndBudgetConfirmation) {
                BudgetExpiredView(
                    budgetManager: budgetManager,
                    isManualEnd: true,
                    onContinueWithSameSettings: {
                        Task { @MainActor in
                            if await budgetManager.createNextPeriodBudget() {
                                showingEndBudgetConfirmation = false
                                // Schedule notifications for the new budget
                                if let budget = budgetManager.currentBudget {
                                    NotificationService.shared.scheduleBudgetEndNotifications(for: budget)
                                }
                            }
                        }
                    },
                    onChangeBudgetSettings: {
                        showingEndBudgetConfirmation = false
                        // Stay in settings to configure new budget
                    },
                    onCancel: {
                        showingEndBudgetConfirmation = false
                    }
                )
            }
            .alertBanner()
            .alert("Sign Out", isPresented: $showingSignOutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    Task {
                        try? await authManager.signOut()
                    }
                }
            } message: {
                Text("Are you sure you want to sign out? Your data is synced to the cloud and will be available when you sign in again.")
            }
            .navigationDestination(isPresented: $showingBudgetSettings) {
                BudgetSettingsView(budgetManager: budgetManager)
            }
            .sheet(isPresented: $showingCurrencySettings) {
                CurrencySettingsView(
                    currentBudget: budgetManager.budget,
                    onUpdateBudget: { updatedBudget in
                        if budgetManager.updateBudget(updatedBudget) {
                            HapticManager.shared.success()
                            notificationManager.showSuccess("Currency updated successfully!")
                        } else {
                            HapticManager.shared.operationFailed()
                            notificationManager.showError("Failed to update currency")
                        }
                    }
                )
            }
            .sheet(isPresented: $showingPeriodSettings) {
                PeriodSettingsView(
                    currentBudget: budgetManager.budget,
                    onUpdateBudget: { updatedBudget in
                        if budgetManager.updateBudget(updatedBudget) {
                            HapticManager.shared.success()
                            notificationManager.showSuccess("Budget period updated successfully!")
                        } else {
                            HapticManager.shared.operationFailed()
                            notificationManager.showError("Failed to update budget period")
                        }
                    }
                )
            }
            .sheet(isPresented: $showingCategorySettings) {
                CategorySettingsView(
                    currentBudget: budgetManager.budget,
                    budgetManager: budgetManager,
                    onUpdateBudget: { updatedBudget in
                        if budgetManager.updateBudget(updatedBudget) {
                            HapticManager.shared.success()
                            notificationManager.showSuccess("Categories updated successfully!")
                        } else {
                            HapticManager.shared.operationFailed()
                            notificationManager.showError("Failed to update categories")
                        }
                    }
                )
            }
            .sheet(isPresented: $showingAddCategory) {
                DSAddCategorySheet(
                    subCategory: nil,
                    allocatedAmount: 0,
                    currency: budgetManager.budget.currency,
                    budgetManager: budgetManager,
                    preSelectedGroup: preSelectedCategoryGroup,
                    onSuccess: {
                        HapticManager.shared.success()
                        notificationManager.showSuccess("Category added successfully!")
                        preSelectedCategoryGroup = nil
                    },
                    onCancel: {
                        preSelectedCategoryGroup = nil
                    }
                )
            }
            .onAppear {
                setupNotifications()
            }
            .toolbar {
                // Only show toolbar items when Budget tab is selected
                if selectedTab == .budget {
                    ToolbarItem(placement: .principal) {
                        VStack(alignment: .center, spacing: 2) {
                            DSText(budgetManager.budget.budgetName, font: .dsHeadline, color: theme.colors.textPrimary)
                            DSText(budgetManager.budget.period.formattedDateRange, font: .dsCaption, color: theme.colors.textSecondary)
                        }
                    }
                    
                    ToolbarItem(placement: .topBarLeading) {
                        SyncStatusIcon(syncState: budgetManager.syncState)
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button(action: {
                                HapticManager.shared.buttonTap()
                                showingCurrencySettings = true
                            }) {
                                Label {
                                    VStack(alignment: .leading) {
                                        DSText("Change Currency", font: .dsBody)
                                        DSText("\(budgetManager.budget.currency.code) - \(budgetManager.budget.currency.name)", font: .dsCaption, color: theme.colors.textSecondary)
                                    }
                                } icon: {
                                    Image(systemName: "dollarsign.circle")
                                }
                            }
                            Button(action: {
                                HapticManager.shared.buttonTap()
                                showingPeriodSettings = true
                            }) {
                                Label {
                                    VStack(alignment: .leading) {
                                        DSText("Budget Period", font: .dsBody)
                                        DSText(budgetManager.budget.period.formattedDateRange, font: .dsCaption, color: theme.colors.textSecondary)
                                    }
                                } icon: {
                                    Image(systemName: "calendar")
                                }
                            }
                            Button(action: {
                                HapticManager.shared.buttonTap()
                                showingCategorySettings = true
                            }) {
                                Label {
                                    VStack(alignment: .leading) {
                                        DSText("Categories", font: .dsBody)
                                        DSText("\(budgetManager.budget.categories.count) Categories", font: .dsCaption, color: theme.colors.textSecondary)
                                    }
                                } icon: {
                                    Image(systemName: "square.grid.2x2")
                                }
                            }
                        } label: {
                            Image(systemName: "pencil.circle")
                                .font(.dsSmallTitle)
                                .fontWeight(.medium)
                                .foregroundColor(theme.colors.textPrimary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Tab Contents

    private var budgetTabContent: some View {
            ScrollView {
                VStack(spacing: DSSpacing.xl) {                    // Budget Section
                    VStack(spacing: DSSpacing.md) {
                        // Section Header with Settings Icon
                        HStack {
                            DSText("Budget Overview", font: .dsSmallTitle, color: theme.colors.textPrimary)
                            Spacer()

                            // Category Group Filter Settings Icon
                            Button(action: {
                                HapticManager.shared.buttonTap()
                                showingCategoryGroupFilter = true
                            }) {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "slider.horizontal.3")
                                        .font(.dsHeadline)
                                        .foregroundColor(theme.colors.textPrimary)
                                        .padding(8)

                                    // Badge indicator when not all groups are selected
                                    if !categoryGroupPreferences.isAllGroupsSelected {
                                        Text("\(categoryGroupPreferences.selectedGroups.count)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 16, height: 16)
                                            .background(theme.colors.primary)
                                            .clipShape(Circle())
                                            .offset(x: 8, y: -4)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, DSSpacing.md)

                        // Budget Overview Hero Card
                        OverviewHeroCard(
                            budgetManager: budgetManager,
                            excludeSavings: expensesOnlyMode,
                            selectedGroups: categoryGroupPreferences.selectedGroups
                        )
                            .padding(.horizontal, DSSpacing.md)
                            .id(budgetManager.budget.id)
                            .transition(.opacity)
                            .animation(.easeOut(duration: 0.2), value: budgetManager.budget.id)
                    }

                    // Chart Section - Category Groups
                    VStack(alignment: .leading, spacing: DSSpacing.md) {
                        // Heading
                        HStack {
                            DSText("Completion by Category", font: .dsSmallTitle, color: theme.colors.textPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, DSSpacing.md)

                        // Single Chart - Group-based spending
                        CategoryGroupBarChart(
                            budgetManager: budgetManager,
                            excludeSavings: expensesOnlyMode,
                            selectedGroups: categoryGroupPreferences.selectedGroups
                        )
                    }
 
                    // All Transactions Link
                    if !budgetManager.getAllTransactions().isEmpty {
                        DSButton(
                            "View All Transactions",
                            fullWidth: true
                        ) {
                            HapticManager.shared.buttonTap()
                            Task { @MainActor in
                                showingAllTransactions = true
                            }
                        }
                        .padding(.horizontal, DSSpacing.md)
                    }

                    // Spends Section
                    if !sortedCategoryGroups.isEmpty {
                        VStack(spacing: DSSpacing.md) {
                            // Section Header
                            HStack {
                                DSText("Spends", font: .dsSmallTitle, color: theme.colors.textPrimary)
                                Spacer()
                            }
                            .padding(.horizontal, DSSpacing.md)

                            // Category Group Cards
                            LazyVStack(spacing: DSSpacing.md) {
                                ForEach(sortedCategoryGroups, id: \.self) { group in
                                    CategoryGroupExpendableCard(
                                        group: group,
                                        budgetManager: budgetManager,
                                        isExpanded: expandedGroups.contains(group),
                                        onToggle: {
                                            toggleExpansion(for: group)
                                        },
                                        onSubCategoryTap: { subCategory in
                                            HapticManager.shared.buttonTap()
                                            selectedCategory = subCategory
                                        },
                                        onAddCategory: { group in
                                            HapticManager.shared.buttonTap()
                                            preSelectedCategoryGroup = group
                                            showingAddCategory = true
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, DSSpacing.md)
                            .id(budgetManager.budget.id)
                            .transition(.opacity)
                            .animation(.easeOut(duration: 0.2), value: budgetManager.budget.id)
                        }
                    }
                    
                    // Bottom spacing
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 16)
                }.padding(.top, DSSpacing.lg)
            }
            .refreshable {
                await budgetManager.refreshFromSupabase()
            }
        .background(theme.colors.background)
    }

    private var analysisTabContent: some View {
        VStack(spacing: 0) {
            // Page Title
            HStack {
                DSText("Analysis", font: .dsLargeTitle, color: theme.colors.textPrimary)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal, DSSpacing.md)
            .padding(.top, DSSpacing.md)
            .padding(.bottom, DSSpacing.xs)

            ScrollView {
                VStack(spacing: DSSpacing.xl) {
                    DSCard {
                        VStack(spacing: DSSpacing.sm) {
                            Image(systemName: "chart.bar.xaxis")
                                .font(.dsLargeTitle)
                                .foregroundColor(theme.colors.textSecondary.opacity(0.6))

                            DSText("Analysis Coming Soon", font: .dsBody, color: theme.colors.textPrimary)
                                .fontWeight(.medium)
                            DSText("Detailed spending analysis and insights will be available here", font: .dsCaption, color: theme.colors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                    .padding(.horizontal, DSSpacing.md)

                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 100)
                }
            }
        }
        .background(theme.colors.background)
    }

    private var settingsTabContent: some View {
        VStack(spacing: 0) {
            // Page Title
            HStack {
                DSText("Settings", font: .dsLargeTitle, color: theme.colors.textPrimary)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal, DSSpacing.md)
            .padding(.top, DSSpacing.md)
            .padding(.bottom, DSSpacing.xs)

            ScrollView {
                VStack(spacing: DSSpacing.xl) {
                    // Theme Section
                    ThemeSettingsSection()
                        .padding(.horizontal, DSSpacing.md)

                    // Historical Budgets Section (only show if authenticated)
                    SettingsSection(
                        title: "Historical Budgets",
                        currentValue: "",
                        description: "View past budget periods",
                        useSmallText: false,
                        isDisabled: false
                    ) {
                        showingHistoricalBudgets = true
                    }
                    .padding(.horizontal, DSSpacing.md)

                    // Sync Section
                    SyncSection(budgetManager: budgetManager)
                        .padding(.horizontal, DSSpacing.md)

                    // Sign Out Section
                    SignOutSection {
                        showingSignOutConfirmation = true
                    }
                    .padding(.horizontal, DSSpacing.md)

                    // End Budget Section (only for current budget)
                    if budgetManager.isViewingMostRecentBudget() {
                        EndBudgetSection {
                            showingEndBudgetConfirmation = true
                        }
                        .padding(.horizontal, DSSpacing.md)
                    }

                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 100)
                }
                .padding(.top, DSSpacing.xs)
            }
        }
        .background(theme.colors.background)
    }


    // MARK: - Setup Methods

    private func setupNotifications() {
        // Request notification permission if not already granted
        Task {
            if NotificationService.shared.authorizationStatus == .notDetermined {
                await NotificationService.shared.requestNotificationPermission()
            }

            // Schedule smart daily reminders based on recent activity
            let transactions = budgetManager.getAllTransactions()
            NotificationService.shared.scheduleSmartDailyReminder(basedOnTransactions: transactions)

            // Schedule budget end notifications for current budget
            if let currentBudget = budgetManager.currentBudget {
                NotificationService.shared.scheduleBudgetEndNotifications(for: currentBudget)
            }

            // Apply current notification settings
            let settings = UserDefaults.standard.notificationSettings
            applyNotificationSettings(settings)
        }
    }

    private func applyNotificationSettings(_ settings: NotificationSettings) {
        let service = NotificationService.shared

        if settings.dailyRemindersEnabled {
            let components = Calendar.current.dateComponents([.hour, .minute], from: settings.dailyReminderTime)
            service.scheduleDailyExpenseReminder(
                at: components.hour ?? 19,
                minute: components.minute ?? 0,
                isEnabled: true
            )
        }

        if settings.weeklyReviewEnabled {
            let components = Calendar.current.dateComponents([.hour, .minute], from: settings.weeklyReviewTime)
            service.scheduleWeeklyReview(
                on: settings.weeklyReviewDay,
                at: components.hour ?? 10,
                minute: components.minute ?? 0,
                isEnabled: true
            )
        }
    }

    private func toggleExpansion(for group: CategoryGroup) {
        withAnimation(.easeOut(duration: 0.3)) {
            if expandedGroups.contains(group) {
                expandedGroups.remove(group)
            } else {
                expandedGroups.insert(group)
            }
        }
    }
}

// MARK: - Theme Settings Component

struct ThemeSettingsSection: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var systemColorScheme

    var body: some View {
        DSCard(padding: 8) {
            HStack(alignment: .center, spacing: DSSpacing.md) {
                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    DSText("Theme", font: .dsHeadline, color: theme.colors.textPrimary)
                    DSText("Choose your app appearance", font: .dsCaption, color: theme.colors.textSecondary)
                }

                Spacer()

                HStack(spacing: DSSpacing.sm) {
                    Image(systemName: theme.themePreference == .light ? "sun.max.fill" : "moon.fill")
                        .font(.dsBody)
                        .foregroundColor(theme.colors.textSecondary)

                    Toggle("", isOn: Binding(
                        get: { theme.themePreference == .dark },
                        set: { isDark in
                            HapticManager.shared.buttonTap()
                            theme.themePreference = isDark ? .dark : .light
                            theme.updateColorScheme(systemScheme: systemColorScheme)
                        }
                    ))
                    .labelsHidden()
                    .tint(theme.colors.primary)
                }
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.sm)
        }
    }
}

// MARK: - Tab Bar Button Component
