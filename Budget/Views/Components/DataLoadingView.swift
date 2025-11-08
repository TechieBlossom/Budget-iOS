//
//  DataLoadingView.swift
//  Budget
//
//  Loading view with shimmer effect for initial data fetch
//

import SwiftUI

struct DataLoadingView: View {
    @Environment(\.appTheme) private var theme
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            theme.colors.background
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Logo or app icon area
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 60))
                    .foregroundStyle(theme.colors.textSecondary)
                    .opacity(0.3)

                VStack(spacing: 12) {
                    DSText(
                        "Loading your budget",
                        font: .dsSmallTitle,
                        color: theme.colors.textPrimary
                    )

                    DSText(
                        "Syncing data from cloud...",
                        font: .dsBody,
                        color: theme.colors.textSecondary
                    )
                }

                // Loading indicator
                ProgressView()
                    .tint(theme.colors.textPrimary)
                    .scaleEffect(1.2)
                    .padding(.top, 8)

                // Shimmer cards preview
                VStack(spacing: 12) {
                    shimmerCard(height: 120)
                    shimmerCard(height: 80)
                    shimmerCard(height: 80)
                }
                .padding(.top, 40)
            }
            .padding(.horizontal, 24)
        }
    }

    @ViewBuilder
    private func shimmerCard(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(theme.colors.surface)
            .frame(height: height)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0),
                                Color.white.opacity(0.3),
                                Color.white.opacity(0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: isAnimating ? 400 : -400)
            )
            .clipped()
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    isAnimating = true
                }
            }
    }
}

#Preview {
    DataLoadingView()
        .environment(\.appTheme, AppTheme.shared)
}
