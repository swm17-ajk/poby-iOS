import SwiftUI

enum AppColors {
    static let cameraBlack = Color(hex: 0x0A0A0A)

    static let inkPrimary   = Color(hex: 0x0F0F10)
    static let inkSecondary = Color(hex: 0x3A3A3C)
    static let inkTertiary  = Color(hex: 0x8E8E93)

    static let mint     = Color(hex: 0x4DD6B6)
    static let mintDeep = Color(hex: 0x0D2B25)

    static let danger = Color(hex: 0xFF5F57)

    static let guideDefault = Color.white
    static let guideMatched = mint

    enum Warm {
        static let paper        = Color(hex: 0xF7F5EF)
        static let paper2       = Color(hex: 0xF0EEE5)
        static let hairline     = Color(hex: 0xE6E3D8)
        static let grabber      = Color(hex: 0xD6D3C8)
        static let doneActive   = Color(hex: 0x0A8A72)
        static let doneInactive = Color(hex: 0xC5C0B3)
    }

    enum Modern {
        static let paper        = Color(hex: 0xF2F2F7)
        static let paper2       = Color.white
        static let hairline     = Color(hex: 0xE5E5EA)
        static let grabber      = Color(hex: 0xD1D1D6)
        static let doneActive   = Color(hex: 0x0A7D68)
        static let doneInactive = Color(hex: 0xC7C7CC)
    }
}

private extension Color {
    init(hex: Int, opacity: Double = 1) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >>  8) & 0xFF) / 255,
            blue:  Double( hex        & 0xFF) / 255,
            opacity: opacity
        )
    }
}
