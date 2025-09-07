import SwiftUI

struct DSCard<Content: View>: View {
    let padding: CGFloat
    let content: Content
    
    @Environment(\.appTheme) private var theme
    
    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.padding = padding
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(theme.colors.card)
            .cornerRadius(12)
            .shadow(color: theme.colors.secondaryText.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    VStack(spacing: 16) {
        DSCard {
            VStack(alignment: .leading, spacing: 8) {
                DSText("Card Title", font: .dsHeadline)
                DSText("This is some card content with secondary text.", font: .dsBody, color: AppTheme.shared.colors.secondaryText)
            }
        }
        
        DSCard {
            HStack {
                DSText("Simple Card", font: .dsBody)
                Spacer()
                DSText("Value", font: .dsBody, color: AppTheme.shared.colors.secondaryText)
            }
        }
    }
    .padding()
    .background(AppTheme.shared.colors.background)
}
