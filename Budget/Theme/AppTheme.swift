import SwiftUI

enum ThemePreference: String, Codable, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var displayName: String {
        return rawValue
    }
}

@Observable
class AppTheme {
    var colorScheme: ColorScheme = .light
    var themePreference: ThemePreference = .system {
        didSet {
            UserDefaults.standard.set(themePreference.rawValue, forKey: "themePreference")
        }
    }

    static let shared = AppTheme()

    private init() {
        // Load saved theme preference
        if let savedPreference = UserDefaults.standard.string(forKey: "themePreference"),
           let preference = ThemePreference(rawValue: savedPreference) {
            self.themePreference = preference
        }
    }

    func updateColorScheme(systemScheme: ColorScheme) {
        switch themePreference {
        case .system:
            colorScheme = systemScheme
        case .light:
            colorScheme = .light
        case .dark:
            colorScheme = .dark
        }
    }

    var colors: ThemeColors {
        switch colorScheme {
        case .light:
            return ThemeColors.light
        case .dark:
            return ThemeColors.dark
        @unknown default:
            return ThemeColors.light
        }
    }
}

struct ThemeColors {
    // Brand & Interactive Colors
    let primary: Color              // Brand color - main CTA, interactive elements
    let primaryLight: Color         // Lighter variant for hover/disabled states
    let primaryDark: Color          // Darker variant for pressed states

    // Text Colors
    let textPrimary: Color          // Primary text - headings, important content
    let textSecondary: Color        // Secondary text - descriptions, labels
    let textTertiary: Color         // Tertiary text - hints, placeholders

    // Background Colors
    let background: Color           // Main background
    let backgroundSecondary: Color  // Secondary background for sections
    let surface: Color              // Card/elevated surfaces
    let surfaceVariant: Color       // Variant surface for subtle differentiation

    // Semantic Colors
    let success: Color              // Success states, positive actions
    let warning: Color              // Warning states, caution
    let error: Color                // Error states, destructive actions
    let info: Color                 // Info states, neutral notifications

    // Utility Colors
    let divider: Color              // Dividers, borders
    let overlay: Color              // Overlays, modals background

    static let light = ThemeColors(
        // Brand Colors - Professional Blue
        primary: Color(hex: "0d47a1"),
        primaryLight: Color(hex: "42a5f5"),
        primaryDark: Color(hex: "01579b"),

        // Text Colors - Dark grays for readability
        textPrimary: Color(hex: "1a1a1a"),
        textSecondary: Color(hex: "666666"),
        textTertiary: Color(hex: "999999"),

        // Background Colors - Light, clean palette
        background: Color(hex: "f5f5f5"),
        backgroundSecondary: Color(hex: "e8e8e8"),
        surface: Color(hex: "ffffff"),
        surfaceVariant: Color(hex: "f9f9f9"),

        // Semantic Colors - Standard palette
        success: Color(hex: "4caf50"),
        warning: Color(hex: "ff9800"),
        error: Color(hex: "f44336"),
        info: Color(hex: "2196f3"),

        // Utility Colors
        divider: Color(hex: "e0e0e0"),
        overlay: Color(hex: "000000").opacity(0.5)
    )

    static let dark = ThemeColors(
        // Brand Colors - Same across themes
        primary: Color(hex: "0d47a1"),
        primaryLight: Color(hex: "42a5f5"),
        primaryDark: Color(hex: "01579b"),

        // Text Colors - Light grays for dark mode
        textPrimary: Color(hex: "ffffff"),
        textSecondary: Color(hex: "b3b3b3"),
        textTertiary: Color(hex: "808080"),

        // Background Colors - Dark palette
        background: Color(hex: "121212"),
        backgroundSecondary: Color(hex: "1e1e1e"),
        surface: Color(hex: "2c2c2c"),
        surfaceVariant: Color(hex: "383838"),

        // Semantic Colors - Adjusted for dark mode
        success: Color(hex: "66bb6a"),
        warning: Color(hex: "ffa726"),
        error: Color(hex: "ef5350"),
        info: Color(hex: "42a5f5"),

        // Utility Colors
        divider: Color(hex: "444444"),
        overlay: Color(hex: "000000").opacity(0.7)
    )
}

// Note: Color(hex:) extension is defined in CategoryColors.swift

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue = AppTheme.shared
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}
