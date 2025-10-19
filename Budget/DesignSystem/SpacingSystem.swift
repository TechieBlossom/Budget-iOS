import SwiftUI

/// Design System Spacing
/// Provides consistent spacing values throughout the app
struct DSSpacing {
    /// 4pt - Minimal spacing for tight layouts
    static let xxs: CGFloat = 4

    /// 8pt - Small spacing between related elements
    static let xs: CGFloat = 8

    /// 12pt - Medium spacing for grouped content
    static let sm: CGFloat = 12

    /// 16pt - Standard spacing (most common)
    static let md: CGFloat = 16

    /// 20pt - Medium-large spacing
    static let lg: CGFloat = 20

    /// 24pt - Large spacing between sections
    static let xl: CGFloat = 24

    /// 32pt - Extra large spacing
    static let xxl: CGFloat = 32

    /// 40pt - Maximum spacing for major sections
    static let xxxl: CGFloat = 40
}

/// Edge Insets using DS spacing
extension EdgeInsets {
    static var dsXXS: EdgeInsets { EdgeInsets(top: DSSpacing.xxs, leading: DSSpacing.xxs, bottom: DSSpacing.xxs, trailing: DSSpacing.xxs) }
    static var dsXS: EdgeInsets { EdgeInsets(top: DSSpacing.xs, leading: DSSpacing.xs, bottom: DSSpacing.xs, trailing: DSSpacing.xs) }
    static var dsSM: EdgeInsets { EdgeInsets(top: DSSpacing.sm, leading: DSSpacing.sm, bottom: DSSpacing.sm, trailing: DSSpacing.sm) }
    static var dsMD: EdgeInsets { EdgeInsets(top: DSSpacing.md, leading: DSSpacing.md, bottom: DSSpacing.md, trailing: DSSpacing.md) }
    static var dsLG: EdgeInsets { EdgeInsets(top: DSSpacing.lg, leading: DSSpacing.lg, bottom: DSSpacing.lg, trailing: DSSpacing.lg) }
    static var dsXL: EdgeInsets { EdgeInsets(top: DSSpacing.xl, leading: DSSpacing.xl, bottom: DSSpacing.xl, trailing: DSSpacing.xl) }
    static var dsXXL: EdgeInsets { EdgeInsets(top: DSSpacing.xxl, leading: DSSpacing.xxl, bottom: DSSpacing.xxl, trailing: DSSpacing.xxl) }
    static var dsXXXL: EdgeInsets { EdgeInsets(top: DSSpacing.xxxl, leading: DSSpacing.xxxl, bottom: DSSpacing.xxxl, trailing: DSSpacing.xxxl) }
}
