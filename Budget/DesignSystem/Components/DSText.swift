import SwiftUI

struct DSText: View {
    let text: String
    let font: Font
    let color: Color?
    
    @Environment(\.appTheme) private var theme
    
    init(_ text: String, font: Font = .dsBody, color: Color? = nil) {
        self.text = text
        self.font = font
        self.color = color
    }
    
    var body: some View {
        Text(text)
            .font(font)
            .foregroundColor(textColor)
    }
    
    private var textColor: Color {
        return color ?? theme.colors.primaryText
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        DSText("Large Title", font: .dsLargeTitle)
        DSText("Title", font: .dsTitle)
        DSText("Headline", font: .dsHeadline)
        DSText("Body text for regular content", font: .dsBody)
        DSText("Secondary text for descriptions", font: .dsBody, color: AppTheme.shared.colors.secondaryText)
        DSText("Caption text for small details", font: .dsCaption)
    }
    .padding()
    .background(AppTheme.shared.colors.background)
}