import SwiftUI

struct TypographyStyles {
    private static func inriaSans(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .bold:
            return Font.custom("InriaSans-Bold", size: size)
        case .light:
            return Font.custom("InriaSans-Light", size: size)
        default:
            return Font.custom("InriaSans-Regular", size: size)
        }
    }
    
    static let largeTitle = inriaSans(size: 34, weight: .bold)
    static let title = inriaSans(size: 28, weight: .bold)
    static let smallTitle = inriaSans(size: 22, weight: .bold)
    static let headline = inriaSans(size: 17, weight: .bold)
    static let body = inriaSans(size: 17)
    static let subtitle = inriaSans(size: 14)
    static let caption = inriaSans(size: 12)
}

extension Font {
    static var dsLargeTitle: Font { TypographyStyles.largeTitle }
    static var dsTitle: Font { TypographyStyles.title }
    static var dsSmallTitle: Font { TypographyStyles.smallTitle }
    static var dsHeadline: Font { TypographyStyles.headline }
    static var dsBody: Font { TypographyStyles.body }
    static var dsSubtitle: Font { TypographyStyles.subtitle }
    static var dsCaption: Font { TypographyStyles.caption }
}
