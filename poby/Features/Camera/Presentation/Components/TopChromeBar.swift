import SwiftUI

struct TopChromeBar: View {
    let ratioLabel: String
    let isFlashOn: Bool
    let onRatioTap: () -> Void
    let onFlashTap: () -> Void

    var body: some View {
        HStack {
            Spacer().frame(width: 36)
            Spacer()

            Button(action: onRatioTap) {
                Text(ratioLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.gapS)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.10))
                    )
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
            }
            .buttonStyle(.plain)

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
}
