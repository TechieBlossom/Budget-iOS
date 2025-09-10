import SwiftUI

struct DSHeader: View {
    let title: String
    let subtitle: String?
    let onBack: () -> Void
    let trailingContent: (() -> AnyView)?
    
    @Environment(\.appTheme) private var theme
    
    init(
        title: String,
        subtitle: String? = nil,
        onBack: @escaping () -> Void,
        @ViewBuilder trailingContent: @escaping () -> some View = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.onBack = onBack
        self.trailingContent = { AnyView(trailingContent()) }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                DSIconButton(type: .back) {
                    onBack()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    DSText(title, 
                          font: subtitle != nil ? .dsHeadline : .dsTitle, 
                          color: theme.colors.primaryText)
                        .fontWeight(.medium)
                    
                    if let subtitle = subtitle {
                        DSText(subtitle, font: .dsSubtitle, color: theme.colors.secondaryText)
                    }
                }
                
                Spacer()
                
                if let trailingContent = trailingContent {
                    trailingContent()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 24)
    }
}

#Preview {
    VStack(spacing: 20) {
        DSHeader(
            title: "Budget Settings",
            subtitle: "September Budget",
            onBack: {}
        )
        
        DSHeader(
            title: "Budget Analysis",
            onBack: {}
        ) {
            Button(action: {}) {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(AppTheme.shared.colors.primaryText)
            }
        }
    }
    .background(AppTheme.shared.colors.background)
}