import SwiftUI

struct DSCategoryGroupFilterSheet: View {
    @ObservedObject var preferences: CategoryGroupPreferences
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @State private var tempSelectedGroups: Set<CategoryGroup>

    init(preferences: CategoryGroupPreferences) {
        self.preferences = preferences
        self._tempSelectedGroups = State(initialValue: preferences.selectedGroups)
    }

    private var hasChanges: Bool {
        tempSelectedGroups != preferences.selectedGroups
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: DSSpacing.sm) {
                    ForEach(CategoryGroup.allCases) { group in
                        Button(action: {
                            HapticManager.shared.buttonTap()
                            toggleGroup(group)
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

                                // Checkbox
                                Image(systemName: tempSelectedGroups.contains(group) ? "checkmark.circle.fill" : "circle")
                                    .font(.dsHeadline)
                                    .foregroundColor(tempSelectedGroups.contains(group) ? theme.colors.primary : theme.colors.textSecondary)
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
                    DSText("Filter by Category Group", font: .dsHeadline, color: theme.colors.textPrimary)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Image(systemName: "xmark")
                        .font(.dsHeadline)
                        .foregroundColor(theme.colors.textPrimary)
                        .onTapGesture {
                            dismiss()
                        }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        HapticManager.shared.buttonTap()
                        saveAndDismiss()
                    }) {
                        Image(systemName: "checkmark")
                            .font(.dsHeadline)
                            .foregroundColor(hasChanges ? theme.colors.primary : theme.colors.textSecondary.opacity(0.3))
                    }
                    .disabled(!hasChanges)
                }
            }
        }
    }

    private func toggleGroup(_ group: CategoryGroup) {
        // Ensure at least one group remains selected
        if tempSelectedGroups.contains(group) && tempSelectedGroups.count > 1 {
            tempSelectedGroups.remove(group)
        } else if !tempSelectedGroups.contains(group) {
            tempSelectedGroups.insert(group)
        } else {
            // If trying to deselect the last group, show haptic feedback
            HapticManager.shared.error()
        }
    }

    private func saveAndDismiss() {
        preferences.selectedGroups = tempSelectedGroups
        dismiss()
    }
}

#Preview {
    @Previewable @StateObject var preferences = CategoryGroupPreferences()

    DSCategoryGroupFilterSheet(preferences: preferences)
}
