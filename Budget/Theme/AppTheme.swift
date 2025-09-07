import SwiftUI

@Observable
class AppTheme {
    var colorScheme: ColorScheme = .light
    
    static let shared = AppTheme()
    
    private init() {}
    
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
    let primaryText: Color
    let secondaryText: Color
    let background: Color
    let card: Color
    let accent: Color
    
    static let light = ThemeColors(
        primaryText: Color(hex: "402D31"),
        secondaryText: Color(hex: "5D4147"),
        background: Color(hex: "D5D5D5"),
        card: Color(hex: "F2F2F2"),
        accent: Color(hex: "F2CDAC")
    )
    
    static let dark = ThemeColors(
        primaryText: Color(hex: "402D31"),
        secondaryText: Color(hex: "5D4147"),
        background: Color(hex: "D5D5D5"),
        card: Color(hex: "F2F2F2"),
        accent: Color(hex: "F2CDAC")
    )
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue = AppTheme.shared
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}
