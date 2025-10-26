//
//  HistoricalBudgetsView.swift
//  Budget
//
//  Created for Supabase integration - Phase 8
//

import SwiftUI
import Supabase

/// View model for managing historical budgets
@MainActor
@Observable
class HistoricalBudgetsViewModel {
    var historicalBudgets: [SupabaseBudget] = []
    var isLoading = false
    var errorMessage: String?

    private let supabase = SupabaseClientManager.shared.client

    /// Fetch historical budgets (inactive budgets only)
    func fetchHistoricalBudgets() async {
        isLoading = true
        errorMessage = nil

        do {
            // Get current user
            let session = try await supabase.auth.session
            let userId = session.user.id

            // Fetch inactive budgets only, sorted by start date descending
            let budgets: [SupabaseBudget] = try await supabase
                .from("budgets")
                .select()
                .eq("user_id", value: userId)
                .eq("is_active", value: false)
                .order("start_date", ascending: false)
                .execute()
                .value

            historicalBudgets = budgets
            isLoading = false

        } catch {
            errorMessage = "Failed to load historical budgets: \(error.localizedDescription)"
            isLoading = false
        }
    }
}

/// List view displaying all historical (inactive) budgets
struct HistoricalBudgetsView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = HistoricalBudgetsViewModel()
    @State private var selectedBudget: SupabaseBudget?

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                // Loading state
                VStack(spacing: DSSpacing.md) {
                    ProgressView()
                        .tint(theme.colors.primary)
                    DSText("Loading historical budgets...", font: .dsBody, color: theme.colors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if let errorMessage = viewModel.errorMessage {
                // Error state
                VStack(spacing: DSSpacing.md) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.dsLargeTitle)
                        .foregroundColor(theme.colors.textSecondary.opacity(0.6))

                    DSText("Error Loading Budgets", font: .dsHeadline, color: theme.colors.textPrimary)
                        .fontWeight(.medium)

                    DSText(errorMessage, font: .dsBody, color: theme.colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DSSpacing.xl)

                    DSButton("Try Again", style: .primary) {
                        Task {
                            await viewModel.fetchHistoricalBudgets()
                        }
                    }
                    .padding(.top, DSSpacing.md)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if viewModel.historicalBudgets.isEmpty {
                // Empty state
                VStack(spacing: DSSpacing.md) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.dsLargeTitle)
                        .foregroundColor(theme.colors.textSecondary.opacity(0.6))

                    DSText("No Historical Budgets", font: .dsHeadline, color: theme.colors.textPrimary)
                        .fontWeight(.medium)

                    DSText("Your past budgets will appear here once you complete or end a budget period", font: .dsBody, color: theme.colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DSSpacing.xl)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else {
                // Budgets list
                ScrollView {
                    LazyVStack(spacing: DSSpacing.md) {
                        ForEach(viewModel.historicalBudgets, id: \.id) { budget in
                            HistoricalBudgetRow(budget: budget) {
                                selectedBudget = budget
                            }
                        }
                    }
                    .padding(.horizontal, DSSpacing.md)
                    .padding(.vertical, DSSpacing.md)
                }
            }
        }
        .background(theme.colors.background)
        .navigationTitle("Historical Budgets")
        .navigationBarTitleDisplayMode(.inline)
        .customNavigationBarAppearance()
        .task {
            await viewModel.fetchHistoricalBudgets()
        }
        .navigationDestination(item: $selectedBudget) { budget in
            HistoricalBudgetDetailView(budget: budget)
        }
    }
}

/// Row component for displaying a single historical budget
struct HistoricalBudgetRow: View {
    let budget: SupabaseBudget
    let action: () -> Void

    @Environment(\.appTheme) private var theme

    private var budgetPeriod: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: budget.startDate)) - \(formatter.string(from: budget.endDate))"
    }

    private var budgetTypeIcon: String {
        budget.budgetType == "monthly" ? "calendar" : "calendar.badge.clock"
    }

    var body: some View {
        Button(action: action) {
            DSCard(padding: 8) {
                HStack(spacing: DSSpacing.md) {
                    // Icon
                    Image(systemName: budgetTypeIcon)
                        .font(.dsTitle)
                        .foregroundColor(theme.colors.primary)
                        .frame(width: 40, height: 40)
                        .background(theme.colors.primary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Budget info
                    VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                        DSText(budget.budgetName, font: .dsHeadline, color: theme.colors.textPrimary)
                            .fontWeight(.medium)

                        DSText(budgetPeriod, font: .dsCaption, color: theme.colors.textSecondary)

                        HStack(spacing: DSSpacing.xs) {
                            DSText("Currency:", font: .dsCaption, color: theme.colors.textSecondary)
                            DSText("\(budget.currencyCode) (\(budget.currencySymbol))", font: .dsCaption, color: theme.colors.textPrimary)
                                .fontWeight(.medium)
                        }
                    }

                    Spacer()

                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(.dsSubtitle)
                        .foregroundColor(theme.colors.textSecondary)
                }
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.sm)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NavigationStack {
        HistoricalBudgetsView()
            .environment(\.appTheme, AppTheme.shared)
    }
}
