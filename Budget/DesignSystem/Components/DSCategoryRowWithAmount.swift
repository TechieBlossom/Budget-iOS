import SwiftUI

// Helper for rounded corners on specific sides
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

struct DSCategoryRowWithAmount: View {
    let subCategory: SubCategory
    let currentAmount: Double
    let currency: Currency
    let onAmountChange: (Double) -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void
    let onToggleCategoryType: (() -> Void)?

    @State private var amountText: String
    @Environment(\.appTheme) private var theme

    init(
        subCategory: SubCategory,
        currentAmount: Double,
        currency: Currency,
        onAmountChange: @escaping (Double) -> Void,
        onDelete: @escaping () -> Void,
        onEdit: @escaping () -> Void,
        onToggleCategoryType: (() -> Void)? = nil
    ) {
        self.subCategory = subCategory
        self.currentAmount = currentAmount
        self.currency = currency
        self.onAmountChange = onAmountChange
        self.onDelete = onDelete
        self.onEdit = onEdit
        self.onToggleCategoryType = onToggleCategoryType
        self._amountText = State(initialValue: currentAmount > 0 ? String(format: "%.2f", currentAmount) : "")
    }

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 0) {
                // Color Border (from category group)
                Rectangle()
                    .fill(subCategory.categoryGroup.color)
                    .frame(width: 8)
                    .cornerRadius(8, corners: [.topLeft, .bottomLeft])

                HStack(spacing: DSSpacing.md) {
                // Category Name and Type
                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    DSText(subCategory.name, font: .dsHeadline, color: theme.colors.textPrimary)

                    // Category Type - Tappable
                    if let toggleAction = onToggleCategoryType {
                        Button(action: toggleAction) {
                            DSText(
                                subCategory.categoryType.displayName,
                                font: .dsCaption,
                                color: subCategory.categoryType == .savings ? theme.colors.primary : theme.colors.textSecondary
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        DSText(
                            subCategory.categoryType.displayName,
                            font: .dsCaption,
                            color: subCategory.categoryType == .savings ? theme.colors.primary : theme.colors.textSecondary
                        )
                    }
                }

                Spacer()

                // Amount Input Field
                TextField("0.00", text: $amountText)
                    .font(.dsHeadline)
                    .foregroundColor(theme.colors.textPrimary)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .padding(.horizontal, DSSpacing.xs)
                    .padding(.vertical, DSSpacing.xs)
                    .frame(width: 100)
                    .background(theme.colors.background)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(theme.colors.textSecondary.opacity(0.3), lineWidth: 1)
                    )
                    .onChange(of: amountText) { _, newValue in
                        let numericValue = Double(newValue) ?? 0.0
                        onAmountChange(numericValue)
                    }

                    // Delete Button
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.body)
                            .foregroundColor(theme.colors.textSecondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, DSSpacing.md)
                .padding(.vertical, DSSpacing.md)
            }
            .background(theme.colors.surface)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    @Previewable @State var amount: Double = 500.0

    let subCategory = SubCategory(
        name: "Groceries",
        categoryGroup: .essentials
    )

    let currency = Currency(code: "USD", name: "US Dollar", symbol: "$")

    VStack(spacing: DSSpacing.md) {
        DSCategoryRowWithAmount(
            subCategory: subCategory,
            currentAmount: amount,
            currency: currency,
            onAmountChange: { newAmount in
                amount = newAmount
                print("Amount changed: \(newAmount)")
            },
            onDelete: {
                print("Delete sub-category")
            },
            onEdit: {
                print("Edit sub-category")
            },
            onToggleCategoryType: {
                print("Toggle category type")
            }
        )
    }
    .padding(DSSpacing.md)
}
