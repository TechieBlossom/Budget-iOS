import SwiftUI

/// Individual removable filter pill component
struct DSActiveFilterPill: View {
    let title: String
    let icon: String?
    let color: Color?
    let onRemove: () -> Void

    @Environment(\.appTheme) private var theme

    init(title: String, icon: String? = nil, color: Color? = nil, onRemove: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.color = color
        self.onRemove = onRemove
    }

    var body: some View {
        HStack(spacing: DSSpacing.xs) {
            // Optional color indicator
            if let color = color {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
            }

            // Optional icon
            if let icon = icon {
                Image(systemName: icon)
                    .font(.dsCaption)
                    .fontWeight(.medium)
                    .foregroundColor(theme.colors.primary)
            }

            // Title
            DSText(title, font: .dsCaption, color: theme.colors.primary)
                .fontWeight(.medium)

            // Remove button
            Button(action: {
                HapticManager.shared.lightImpact()
                onRemove()
            }) {
                Image(systemName: "xmark")
                    .font(.dsCaption)
                    .fontWeight(.bold)
                    .foregroundColor(theme.colors.primary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xs)
        .background(theme.colors.primary.opacity(0.1))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(theme.colors.primary.opacity(0.3), lineWidth: 1)
        )
    }
}

/// Container for displaying active filter pills with "Clear All" option
struct DSActiveFilterPillsView: View {
    let filters: [FilterPillData]
    let onRemoveFilter: (String) -> Void
    let onClearAll: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            HStack {
                DSText("Active Filters", font: .dsCaption, color: theme.colors.textSecondary)
                    .fontWeight(.medium)

                Spacer()

                if filters.count >= 2 {
                    Button(action: {
                        HapticManager.shared.lightImpact()
                        onClearAll()
                    }) {
                        DSText("Clear All", font: .dsCaption, color: theme.colors.primary)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            // Wrapping filter pills
            FlowLayout(spacing: DSSpacing.xs) {
                ForEach(filters, id: \.id) { filter in
                    DSActiveFilterPill(
                        title: filter.title,
                        icon: filter.icon,
                        color: filter.color,
                        onRemove: {
                            onRemoveFilter(filter.id)
                        }
                    )
                }
            }
        }
        .padding(.horizontal, DSSpacing.md)
        .padding(.vertical, DSSpacing.sm)
    }
}

/// Data model for filter pills
struct FilterPillData: Identifiable {
    let id: String
    let title: String
    let icon: String?
    let color: Color?

    init(id: String, title: String, icon: String? = nil, color: Color? = nil) {
        self.id = id
        self.title = title
        self.icon = icon
        self.color = color
    }
}

/// Flow layout for wrapping filter pills
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    // Move to next line
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

#Preview {
    VStack(spacing: DSSpacing.lg) {
        // Single pill
        DSActiveFilterPill(
            title: "Today",
            icon: "calendar",
            onRemove: {}
        )

        // Pill with color
        DSActiveFilterPill(
            title: "Housing",
            color: .blue,
            onRemove: {}
        )

        // Multiple pills in container
        DSActiveFilterPillsView(
            filters: [
                FilterPillData(id: "1", title: "Today", icon: "calendar"),
                FilterPillData(id: "2", title: "Housing", color: .blue),
                FilterPillData(id: "3", title: "Groceries", color: .green),
                FilterPillData(id: "4", title: "$0-100")
            ],
            onRemoveFilter: { _ in },
            onClearAll: {}
        )
    }
    .padding(DSSpacing.md)
    .background(AppTheme.shared.colors.background)
}
