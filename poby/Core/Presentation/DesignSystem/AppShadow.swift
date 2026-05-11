import SwiftUI

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

enum AppShadow {
    static let card     = ShadowStyle(color: .black.opacity(0.12),                radius: 30, x: 0, y: 14)
    static let sheet    = ShadowStyle(color: .black.opacity(0.18),                radius: 30, x: 0, y: -8)
    static let mintGlow = ShadowStyle(color: AppColors.mint.opacity(0.35),        radius: 14, x: 0, y: 6)
    static let shutter  = ShadowStyle(color: .black.opacity(0.35),                radius: 18, x: 0, y: 4)
}

extension View {
    func appShadow(_ style: ShadowStyle) -> some View {
        shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
}
