//
//  ViewExtensions.swift
//  Budget
//
//  Created by Claude on 10/03/2025.
//

import SwiftUI
import UIKit

// MARK: - Navigation Gesture Extension
extension View {
    /// Enables swipe-back gesture even when navigation bar back button is hidden
    func enableSwipeBack() -> some View {
        self.modifier(SwipeBackGestureModifier())
    }

    /// Applies custom font to navigation bar title
    func customNavigationBarAppearance() -> some View {
        self.modifier(CustomNavigationBarModifier())
    }
}

struct SwipeBackGestureModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .gesture(
                DragGesture(minimumDistance: 20, coordinateSpace: .local)
                    .onEnded { value in
                        // Detect swipe from left edge to right (positive translation)
                        if value.translation.width > 100 && abs(value.translation.height) < 50 && value.startLocation.x < 50 {
                            dismiss()
                        }
                    }
            )
    }
}

// MARK: - Custom Navigation Bar Appearance
struct CustomNavigationBarModifier: ViewModifier {
    @Environment(\.appTheme) private var theme

    func body(content: Content) -> some View {
        content
            .onAppear {
                configureNavigationBarAppearance()
            }
    }

    private func configureNavigationBarAppearance() {
        // Configure navigation bar appearance with custom font and pure blur
        let appearance = UINavigationBarAppearance()

        // Use transparent background to enable pure blur
        appearance.configureWithTransparentBackground()

        // Add blur effect - pure system material blur
        let blurEffect = UIBlurEffect()
        appearance.backgroundEffect = blurEffect

        // No background color - rely purely on blur
        appearance.backgroundColor = .clear

        // Large title attributes (InriaSans-Bold)
        let largeTitleFont = UIFont(name: "InriaSans-Bold", size: 34) ?? UIFont.systemFont(ofSize: 34, weight: .bold)
        appearance.largeTitleTextAttributes = [
            .font: largeTitleFont,
            .foregroundColor: UIColor(AppTheme.shared.colors.textPrimary)
        ]

        // Inline title attributes (InriaSans-Bold)
        let inlineTitleFont = UIFont(name: "InriaSans-Bold", size: 17) ?? UIFont.systemFont(ofSize: 17, weight: .semibold)
        appearance.titleTextAttributes = [
            .font: inlineTitleFont,
            .foregroundColor: UIColor(AppTheme.shared.colors.textPrimary)
        ]

        // Remove shadow
        appearance.shadowColor = .clear

        // Apply to all navigation bar states
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance

        // Force immediate update
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.windows.forEach { window in
                window.rootViewController?.setNeedsStatusBarAppearanceUpdate()
            }
        }
    }
}
