//
//  ContentView.swift
//  Budget
//
//  Created by Prateek Sharma on 05/09/2025.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var systemColorScheme
    @State private var authManager = AuthManager()
    @State private var hasCompletedOnboarding = false
    @State private var budgetManager: BudgetManager?
    @State private var showingBudgetExpired = false
    @State private var showingBudgetSettings = false
    @State private var isLoadingInitialData = false
    @State private var showContentWithAnimation = false
    @AppStorage("dismissedExpiredBudgetId") private var dismissedExpiredBudgetId: String = ""
    @AppStorage("hasSeenIntroCarousel") private var hasSeenIntroCarousel = false

    var body: some View {
        Group {
            // Check authentication first
            if !authManager.isAuthenticated {
                if !hasSeenIntroCarousel {
                    IntroCarouselView(onComplete: {
                        // Intro completed, hasSeenIntroCarousel is set to true by the view
                        // AuthView will be shown automatically
                    })
                    .environment(authManager)
                } else {
                    AuthView()
                        .environment(authManager)
                }
            } else if isLoadingInitialData {
                // Show loading view while fetching data from Supabase after login
                DataLoadingView()
                    .transition(.opacity)
            } else if hasCompletedOnboarding, let manager = budgetManager {
                MainAppView(
                    budgetManager: manager,
                    showingBudgetSettings: $showingBudgetSettings
                )
                .environment(authManager)
                .opacity(showContentWithAnimation ? 1 : 0)
                .animation(.easeOut(duration: 0.4), value: showContentWithAnimation)
                .overlay {
                    if showingBudgetExpired {
                        BudgetExpiredView(
                            budgetManager: manager,
                            onContinueWithSameSettings: {
                                Task { @MainActor in
                                    if await manager.createNextPeriodBudget() {
                                        showingBudgetExpired = false
                                        // Schedule notifications for the new budget
                                        if let budget = manager.currentBudget {
                                            NotificationService.shared.scheduleBudgetEndNotifications(for: budget)
                                        }
                                    }
                                }
                            },
                            onChangeBudgetSettings: {
                                showingBudgetSettings = true
                                showingBudgetExpired = false
                            },
                            onViewExpiredBudget: {
                                // Mark budget as dismissed and close overlay
                                dismissedExpiredBudgetId = manager.currentBudget?.id.uuidString ?? ""
                                showingBudgetExpired = false
                            }
                        )
                        .transition(.opacity)
                    }
                }
            } else {
                OnboardingCoordinator(
                    onComplete: { completedBudget in
                        Task { @MainActor in
                            // Create budget manager with the completed budget
                            let manager = BudgetManager(modelContext: modelContext, authManager: authManager)
                            _ = manager.createBudget(completedBudget)
                            budgetManager = manager
                            hasCompletedOnboarding = true
                            showContentWithAnimation = true

                            // Set budget manager reference in auth manager for logout cleanup
                            authManager.budgetManager = manager

                            // Schedule budget end notifications for the new budget
                            NotificationService.shared.scheduleBudgetEndNotifications(for: completedBudget)
                        }
                    }
                )
                .environment(authManager)
            }
        }
        .environment(\.appTheme, AppTheme.shared)
        .task {
            // Check if there are existing budgets to determine onboarding state
            // Only run this if user is authenticated
            if authManager.isAuthenticated {
                await MainActor.run {
                    let manager = BudgetManager(modelContext: modelContext, authManager: authManager)
                    budgetManager = manager

                    // Set budget manager reference in auth manager for logout cleanup
                    authManager.budgetManager = manager

                    if manager.hasExistingBudgets() {
                        // Has cached data - show main screen immediately
                        hasCompletedOnboarding = true
                        showContentWithAnimation = true
                        checkBudgetStatus(manager: manager)
                    } else {
                        // No local data - show loading while syncing
                        isLoadingInitialData = true
                    }
                    // onChange(syncState) will handle sync completion
                }
            }
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            // When user signs in, initialize budget manager and let sync state handle UI updates
            if isAuthenticated {
                Task { @MainActor in
                    // Create manager - this will start sync in background
                    let manager = BudgetManager(modelContext: modelContext, authManager: authManager)
                    budgetManager = manager

                    // Set budget manager reference in auth manager for logout cleanup
                    print("🔗 ContentView: Setting budgetManager reference in AuthManager")
                    authManager.budgetManager = manager
                    print("   ✅ Reference set successfully")

                    // Check immediately for local budgets
                    if manager.hasExistingBudgets() {
                        // Has local data - show main screen immediately
                        hasCompletedOnboarding = true
                        showContentWithAnimation = true
                        checkBudgetStatus(manager: manager)
                    } else {
                        // No local data - show loading while we sync from Supabase
                        isLoadingInitialData = true
                    }
                    // onChange(syncState) will handle completion of sync
                }
            } else {
                // When user signs out, reset state
                budgetManager = nil
                hasCompletedOnboarding = false
                isLoadingInitialData = false
                showContentWithAnimation = false
            }
        }
        .onChange(of: budgetManager?.syncState) { _, newState in
            // When sync completes, handle the result
            guard let manager = budgetManager, let newState = newState else { return }

            switch newState {
            case .synced:
                // Sync completed successfully
                if isLoadingInitialData {
                    // We were waiting for initial sync after login
                    isLoadingInitialData = false

                    if manager.hasExistingBudgets() {
                        // Found remote data - show main screen with fade-in
                        hasCompletedOnboarding = true
                        // Delay to ensure smooth transition
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(100))
                            showContentWithAnimation = true
                        }
                        checkBudgetStatus(manager: manager)
                    } else {
                        // No remote data either - show onboarding
                        hasCompletedOnboarding = false
                    }
                } else if !hasCompletedOnboarding && manager.hasExistingBudgets() {
                    // Data synced while already in app
                    hasCompletedOnboarding = true
                    showContentWithAnimation = true
                    checkBudgetStatus(manager: manager)
                }

            case .error, .offline:
                // Sync failed - if we were loading initial data, decide what to show
                if isLoadingInitialData {
                    isLoadingInitialData = false

                    if manager.hasExistingBudgets() {
                        // Has cached data - show it
                        hasCompletedOnboarding = true
                        showContentWithAnimation = true
                        checkBudgetStatus(manager: manager)
                    } else {
                        // No data at all - show onboarding
                        hasCompletedOnboarding = false
                    }
                }

            case .syncing:
                // Still syncing - keep loading state if appropriate
                break
            }
        }
        .onAppear {
            // Re-check budget status whenever the view appears
            if let manager = budgetManager {
                checkBudgetStatus(manager: manager)
            }
            // Update theme based on system color scheme
            AppTheme.shared.updateColorScheme(systemScheme: systemColorScheme)
        }
        .onChange(of: systemColorScheme) { _, newScheme in
            // Update theme when system color scheme changes
            AppTheme.shared.updateColorScheme(systemScheme: newScheme)
        }
    }

    private func checkBudgetStatus(manager: BudgetManager) {
        let status = manager.checkBudgetStatus()

        switch status {
        case .expired:
            // Only show if user hasn't dismissed this specific budget
            let currentBudgetId = manager.currentBudget?.id.uuidString ?? ""
            if currentBudgetId != dismissedExpiredBudgetId {
                withAnimation(.easeOut(duration: 0.3)) {
                    showingBudgetExpired = true
                }
            }
        case .endingSoon(let daysLeft):
            // For ending soon, we could show a banner or send notification
            // For now, let the notification system handle it
            if daysLeft == 0 {
                // If budget ends today, show a subtle reminder
                print("Budget ends today - user should see this via notification")
            }
        case .active, .noBudget:
            showingBudgetExpired = false
            // Clear dismissed state when viewing active budget
            if !dismissedExpiredBudgetId.isEmpty {
                dismissedExpiredBudgetId = ""
            }
        }
    }
}


#Preview {
    ContentView()
        .modelContainer(for: [BudgetDataModel.self, TransactionDataModel.self])
}
