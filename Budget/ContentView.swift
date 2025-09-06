//
//  ContentView.swift
//  Budget
//
//  Created by Prateek Sharma on 05/09/2025.
//

import SwiftUI

struct ContentView: View {
    @State private var hasCompletedOnboarding = false
    
    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainAppView()
            } else {
                OnboardingCoordinator()
            }
        }
        .environment(\.appTheme, AppTheme.shared)
    }
}

struct MainAppView: View {
    @Environment(\.appTheme) private var theme
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            DSText("Budget App", font: .dsLargeTitle)
                .multilineTextAlignment(.center)
            
            DSText("Main app interface will be implemented here", font: .dsBody, color: theme.colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            
            DSCard {
                VStack(spacing: 16) {
                    DSText("Onboarding Complete! 🎉", font: .dsHeadline)
                    DSText("The main budget tracking interface will be built next.", font: .dsBody)
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            DSButton("Reset to Onboarding (Demo)", style: .outline) {
                // This is just for demo purposes
                UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
                // In a real app, you'd navigate back to onboarding
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
        .background(theme.colors.background)
    }
}

#Preview {
    ContentView()
}
