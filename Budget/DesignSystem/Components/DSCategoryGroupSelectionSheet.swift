import SwiftUI

struct DSCategoryGroupSelectionSheet: View {
    @Binding var selectedGroup: CategoryGroup?
    let onSelect: (CategoryGroup) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: DSSpacing.sm) {
                    ForEach(CategoryGroup.allCases) { group in
                        Button(action: {
                            HapticManager.shared.categorySelected()
                            selectedGroup = group
                            onSelect(group)
                            dismiss()
                        }) {
                            HStack(spacing: DSSpacing.sm) {
                                // Color indicator
                                Circle()
                                    .fill(group.color)
                                    .frame(width: 12, height: 12)

                                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                                    DSText(group.displayName, font: .dsHeadline, color: theme.colors.textPrimary)
                                    DSText(group.description, font: .dsCaption, color: theme.colors.textSecondary)
                                        .lineLimit(2)
                                }

                                Spacer()

                                if selectedGroup == group {
                                    Image(systemName: "checkmark")
                                        .font(.dsHeadline)
                                        .foregroundColor(theme.colors.primary)
                                }
                            }
                            .padding(DSSpacing.md)
                            .background(theme.colors.surface)
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, DSSpacing.md)
                .padding(.top, DSSpacing.md)
            }
            .background(theme.colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    DSText("Select Category Group", font: .dsHeadline, color: theme.colors.textPrimary)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Image(systemName: "xmark")
                        .font(.dsHeadline)
                        .foregroundColor(theme.colors.textPrimary)
                        .onTapGesture {
                            dismiss()
                        }
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var selectedGroup: CategoryGroup? = .essentials

    DSCategoryGroupSelectionSheet(
        selectedGroup: $selectedGroup,
        onSelect: { group in
            print("Selected: \(group.displayName)")
        }
    )
}
