import SwiftUI

struct TypographyStyles {
    static let largeTitle = Font.system(size: 34, weight: .bold)
    static let title = Font.system(size: 28, weight: .bold)
    static let headline = Font.system(size: 17, weight: .semibold)
    static let body = Font.system(size: 17, weight: .regular)
    static let caption = Font.system(size: 12, weight: .regular)
}

extension Font {
    static var dsLargeTitle: Font { TypographyStyles.largeTitle }
    static var dsTitle: Font { TypographyStyles.title }
    static var dsHeadline: Font { TypographyStyles.headline }
    static var dsBody: Font { TypographyStyles.body }
    static var dsCaption: Font { TypographyStyles.caption }
}