import SwiftUI

struct CurvedClipShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let amplitude: CGFloat = 6 // Much gentler curves
        
        // Start from top
        path.move(to: CGPoint(x: amplitude, y: 0))
        
        // 16 waves - each taking 6.25% of height
        // Wave 1 - inward
        path.addQuadCurve(to: CGPoint(x: amplitude, y: rect.height * 0.0625), control: CGPoint(x: 0, y: rect.height * 0.03125))
        // Wave 2 - outward
        path.addQuadCurve(to: CGPoint(x: amplitude, y: rect.height * 0.125), control: CGPoint(x: amplitude * 2, y: rect.height * 0.09375))
        // Wave 3 - inward
        path.addQuadCurve(to: CGPoint(x: amplitude, y: rect.height * 0.1875), control: CGPoint(x: 0, y: rect.height * 0.15625))
        // Wave 4 - outward
        path.addQuadCurve(to: CGPoint(x: amplitude, y: rect.height * 0.25), control: CGPoint(x: amplitude * 2, y: rect.height * 0.21875))
        // Wave 5 - inward
        path.addQuadCurve(to: CGPoint(x: amplitude, y: rect.height * 0.3125), control: CGPoint(x: 0, y: rect.height * 0.28125))
        // Wave 6 - outward
        path.addQuadCurve(to: CGPoint(x: amplitude, y: rect.height * 0.375), control: CGPoint(x: amplitude * 2, y: rect.height * 0.34375))
        // Wave 7 - inward
        path.addQuadCurve(to: CGPoint(x: amplitude, y: rect.height * 0.4375), control: CGPoint(x: 0, y: rect.height * 0.40625))
        // Wave 8 - outward
        path.addQuadCurve(to: CGPoint(x: amplitude, y: rect.height * 0.5), control: CGPoint(x: amplitude * 2, y: rect.height * 0.46875))
        // Wave 9 - inward
        path.addQuadCurve(to: CGPoint(x: amplitude, y: rect.height * 0.5625), control: CGPoint(x: 0, y: rect.height * 0.53125))
        // Wave 10 - outward
        path.addQuadCurve(to: CGPoint(x: amplitude, y: rect.height * 0.625), control: CGPoint(x: amplitude * 2, y: rect.height * 0.59375))
        // Wave 11 - inward
        path.addQuadCurve(to: CGPoint(x: amplitude, y: rect.height * 0.6875), control: CGPoint(x: 0, y: rect.height * 0.65625))
        // Wave 12 - outward
        path.addQuadCurve(to: CGPoint(x: amplitude, y: rect.height * 0.75), control: CGPoint(x: amplitude * 2, y: rect.height * 0.71875))
        // Wave 13 - inward
        path.addQuadCurve(to: CGPoint(x: amplitude, y: rect.height * 0.8125), control: CGPoint(x: 0, y: rect.height * 0.78125))
        // Wave 14 - outward
        path.addQuadCurve(to: CGPoint(x: amplitude, y: rect.height * 0.875), control: CGPoint(x: amplitude * 2, y: rect.height * 0.84375))
        // Wave 15 - inward
        path.addQuadCurve(to: CGPoint(x: amplitude, y: rect.height * 0.9375), control: CGPoint(x: 0, y: rect.height * 0.90625))
        // Wave 16 - outward
        path.addQuadCurve(to: CGPoint(x: amplitude, y: rect.height), control: CGPoint(x: amplitude * 2, y: rect.height * 0.96875))
        
        // Complete the shape
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.closeSubpath()
        
        return path
    }
}

struct BudgetOverviewCard: View {
    let budgetManager: any BudgetManagerProtocol
    @Environment(\.appTheme) private var theme
    
    var body: some View {
        DSCard(padding: 0) {
            GeometryReader { cardGeometry in
                HStack(spacing: 0) {
                    // Left section (80% width) - Budget details
                    VStack(alignment: .leading) {
                        // Budget Amount (without "Budget" label)
                        VStack(alignment: .leading) {
                            DSText(budgetManager.budget.formattedTotalAmount, font: .dsLargeTitle, color: theme.colors.textPrimary)
                        }.padding(.bottom, DSSpacing.md)
                        
                        // Spent Amount
                        VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                            HStack(alignment: .bottom, spacing: DSSpacing.xxs) {
                                DSText("Spent: ", font: .dsBody, color: theme.colors.textSecondary)
                                DSText(String(format: "%.2f", budgetManager.totalSpent), font: .dsHeadline, color: theme.colors.textPrimary)
                            }
                            
                            // Remains Amount
                            HStack(alignment: .bottom, spacing: DSSpacing.xxs) {
                                DSText("Remain: ", font: .dsBody, color: theme.colors.textSecondary)
                                DSText(String(format: "%.2f", budgetManager.totalRemains), font: .dsHeadline, color: theme.colors.textPrimary)
                            }
                        }
                        .padding(.bottom, DSSpacing.xl)
                    }
                    .padding(.leading, DSSpacing.md)
                    .padding(.trailing, DSSpacing.xs)
                    .frame(width: cardGeometry.size.width * 0.7, alignment: .leading)
                    
                    // Right section (30% width) - Vertical Progress with curved clip
                    VStack {
                        // Vertical progress bar
                        GeometryReader { progressGeometry in
                        
                                ZStack(alignment: .bottom) {
                                    // Background
                                    Rectangle()
                                        .fill(theme.colors.primaryLight.opacity(0.3))

                                    // Progress fill (from bottom to top)
                                    Rectangle()
                                        .fill(theme.colors.primary)
                                        .frame(height: max(0, progressGeometry.size.height * max(0, budgetManager.spentPercentage)))
                                        .animation(.easeOut(duration: 0.8), value: budgetManager.spentPercentage)

                                    DSText("\(Int(budgetManager.spentPercentage * 100))%", font: .dsTitle, color: theme.colors.surface)
                                        .padding(.bottom, DSSpacing.xs)
                                        .animation(.easeOut(duration: 0.8), value: budgetManager.spentPercentage)
                                }
                        
                        }
                    }
                    .frame(width: cardGeometry.size.width * 0.3)
                    .clipShape(CurvedClipShape())
                }
            }
            .frame(height: 150)
        }
    }
}

#Preview {
    BudgetOverviewCard(budgetManager: MockBudgetManager(budget: Budget.createSample()))
        .padding(DSSpacing.md)
        .background(AppTheme.shared.colors.background)
}
