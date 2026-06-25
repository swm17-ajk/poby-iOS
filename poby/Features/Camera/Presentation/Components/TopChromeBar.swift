import SwiftUI

struct TopChromeBar: View {
    let selectedRatio: CameraAspectRatio
    let isFlashOn: Bool
    let showFlash: Bool
    let isMatched: Bool
    let onRatioTap: () -> Void
    let onThemeTap: () -> Void
    let onFlashTap: () -> Void
    let palette: AppPalette
    var contentRotation: Angle = .zero

    var body: some View {
        HStack {
            Button(action: onThemeTap) {
                GlassChip(palette: palette) {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: AppMetrics.iconS, weight: .semibold))
                        .foregroundStyle(palette.onSurface)
                        .rotationEffect(contentRotation)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            if isMatched {
                matchPill
            } else {
                ratioChip
            }

            Spacer()

            if showFlash {
                Button(action: onFlashTap) {
                    GlassChip(palette: palette) {
                        Image(systemName: isFlashOn ? "bolt.fill" : "bolt.slash")
                            .font(.system(size: AppMetrics.iconS, weight: .semibold))
                            .foregroundStyle(palette.onSurface)
                            .rotationEffect(contentRotation)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: AppMetrics.iconButton, height: AppMetrics.iconButton)
            }
        }
        .padding(.horizontal, AppSpacing.edge)
        .frame(height: AppMetrics.Camera.topChromeHeight)
    }

    private var ratioChip: some View {
        Button(action: onRatioTap) {
            Text(ratioLabel)
                .font(AppTypography.chip)
                .foregroundStyle(palette.onSurface)
                .padding(.horizontal, AppSpacing.gapS)
                .padding(.vertical, 6)
                .background(Capsule().fill(palette.glassFill))
                .overlay(Capsule().strokeBorder(palette.glassBorder, lineWidth: AppMetrics.borderHairline))
                .rotationEffect(contentRotation)
        }
        .buttonStyle(.plain)
    }

    private var ratioLabel: String { selectedRatio.rawValue }

    private var matchPill: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark")
                .font(.system(size: AppMetrics.iconS - 3, weight: .bold))
                .foregroundStyle(AppColors.mintDeep)
            Text("포즈 매칭")
                .font(AppTypography.pill)
                .foregroundStyle(AppColors.mintDeep)
        }
        .padding(.leading, 9)
        .padding(.trailing, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(AppColors.mint))
        .appShadow(AppShadow.mintGlow)
        .transition(.scale.combined(with: .opacity))
        .rotationEffect(contentRotation)
    }
}
