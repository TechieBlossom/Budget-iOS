import SwiftUI

enum DSHeaderButtonType {
    case back
    case close
    case none
}

struct DSHeader: View {
    let title: String
    let subtitle: String?
    let onBack: (() -> Void)?
    let trailingContent: (() -> AnyView)?
    let buttonType: DSHeaderButtonType

    @Environment(\.appTheme) private var theme

    init(
        title: String,
        subtitle: String? = nil,
        buttonType: DSHeaderButtonType = .close,
        onBack: @escaping () -> Void,
        @ViewBuilder trailingContent: @escaping () -> some View = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.buttonType = buttonType
        self.onBack = onBack
        self.trailingContent = { AnyView(trailingContent()) }
    }

    // Onboarding initializer without button
    init(
        title: String,
        subtitle: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.buttonType = .none
        self.onBack = nil
        self.trailingContent = nil
    }

    var body: some View {
        VStack(spacing: DSSpacing.xs) {
            HStack(spacing: DSSpacing.md) {
                if buttonType != .none, let onBack = onBack {
                    Button(action: {
                        HapticManager.shared.navigationBack()
                        onBack()
                    }) {
                        switch buttonType {
                        case .back:
                            Image(systemName: "chevron.left")
                                .font(.dsSmallTitle)
                                .foregroundColor(theme.colors.primary)
                                .frame(width: 44, height: 44)
                                .background(theme.colors.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        case .close:
                            Image(systemName: "xmark.circle.fill")
                                .font(.dsTitle)
                                .foregroundStyle(theme.colors.textSecondary, theme.colors.surface)
                                .symbolRenderingMode(.palette)
                        case .none:
                            EmptyView()
                        }
                    }
                }

                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    DSText(title,
                          font: subtitle != nil ? .dsHeadline : .dsTitle,
                          color: theme.colors.textPrimary)
                        .fontWeight(.medium)

                    if let subtitle = subtitle {
                        DSText(subtitle, font: .dsSubtitle, color: theme.colors.textSecondary).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                if let trailingContent = trailingContent {
                    trailingContent()
                }
            }
        }
        .padding(.horizontal, DSSpacing.md)
        .padding(.top, DSSpacing.md)
        .padding(.bottom, DSSpacing.xl)
    }
}

#Preview {
    VStack(spacing: DSSpacing.lg) {
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
                    .font(.dsHeadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.shared.colors.textPrimary)
            }
        }
    }
    .background(AppTheme.shared.colors.background)
}
