import SwiftUI

enum AppTypography {
    static let title       = Font.pretendard(.bold,       size: 22)
    static let sectionTitle = Font.pretendard(.semiBold,  size: 19)
    static let body        = Font.pretendard(.medium,     size: 15)
    static let bodyEmphasis = Font.pretendard(.semiBold,  size: 15)
    static let caption     = Font.pretendard(.medium,     size: 12)
    static let captionMono = Font.system(size: 12, weight: .medium, design: .monospaced)

    static let buttonPrimary   = Font.pretendard(.bold,     size: 14)
    static let buttonSecondary = Font.pretendard(.semiBold, size: 14)

    static let pill            = Font.pretendard(.bold,     size: 12)
    static let chip            = Font.pretendard(.semiBold, size: 13)

    static let hintLarge       = Font.pretendard(.semiBold, size: 17)
    static let hintSmall       = Font.pretendard(.medium,   size: 13)

    static let alertTitle      = Font.pretendard(.semiBold, size: 17)
    static let alertButton     = Font.system(size: 17)
}

enum PretendardWeight: String {
    case regular   = "Pretendard-Regular"
    case medium    = "Pretendard-Medium"
    case semiBold  = "Pretendard-SemiBold"
    case bold      = "Pretendard-Bold"
    case extraBold = "Pretendard-ExtraBold"
}

extension Font {
    static func pretendard(_ weight: PretendardWeight, size: CGFloat) -> Font {
        .custom(weight.rawValue, size: size)
    }
}
