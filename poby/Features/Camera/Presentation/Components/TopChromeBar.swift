import SwiftUI

struct TopChromeBar: View {
    let ratioLabel: String
    let isFlashOn: Bool
    let isMatched: Bool
    let onRatioTap: () -> Void
    let onFlashTap: () -> Void

    var body: some View {
        HStack {
            Spacer().frame(width: 36)
            Spacer()

            if isMatched {
                matchPill
            } else {
                ratioChip
            }

            Spacer()

            Button(action: onFlashTap) {
                GlassChip {
                    Image(systemName: isFlashOn ? "bolt.fill" : "bolt.slash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.edge)
        .frame(height: AppMetrics.Camera.topChromeHeight)
    }

    private var ratioChip: some View {
        Button(action: onRatioTap) {
            Text(ratioLabel)
                .font(AppTypography.chip)
                .foregroundStyle(.white)
                .padding(.horizontal, AppSpacing.gapS)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.white.opacity(0.10)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var matchPill: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
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
    }
}
