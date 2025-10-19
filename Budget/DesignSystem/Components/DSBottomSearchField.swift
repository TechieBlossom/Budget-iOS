import SwiftUI

/// Bottom-positioned search field with liquid glass effect following HIG guidelines
/// Reference: https://developer.apple.com/design/human-interface-guidelines/search-fields
struct DSBottomSearchField: View {
    @Binding var text: String
    let placeholder: String
    let onSearchTap: () -> Void

    @Environment(\.appTheme) private var theme
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            // Search icon
            Image(systemName: "magnifyingglass")
                .font(.dsHeadline)
                .foregroundColor(theme.colors.textSecondary)

            // Text field
            TextField(placeholder, text: $text)
                .font(.dsHeadline)
                .foregroundColor(theme.colors.textPrimary)
                .accentColor(theme.colors.primary)
                .focused($isFocused)
                .onTapGesture {
                    onSearchTap()
                }

            // Clear button
            if !text.isEmpty {
                Button(action: {
                    HapticManager.shared.lightImpact()
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.dsHeadline)
                        .foregroundColor(theme.colors.textSecondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, DSSpacing.md)
        .padding(.vertical, DSSpacing.sm)
        .background(
            // Liquid glass effect
            ZStack {
                // Blur layer
                theme.colors.surface
                    .opacity(0.95)

                // Subtle gradient overlay
                LinearGradient(
                    colors: [
                        theme.colors.surface.opacity(0.8),
                        theme.colors.surface.opacity(0.6)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .blendMode(.overlay)
            }
            .cornerRadius(12)
            .shadow(color: theme.colors.textPrimary.opacity(0.08), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.colors.divider.opacity(0.5), lineWidth: 0.5)
        )
        .padding(.horizontal, DSSpacing.md)
        .padding(.bottom, DSSpacing.sm)
    }
}

#Preview {
    VStack {
        Spacer()

        DSBottomSearchField(
            text: .constant(""),
            placeholder: "Search transactions...",
            onSearchTap: {}
        )
    }
    .background(AppTheme.shared.colors.background)
}
