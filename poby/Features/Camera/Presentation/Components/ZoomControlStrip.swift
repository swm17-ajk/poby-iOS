import SwiftUI

struct ZoomControlStrip: View {
    let zooms: [Double]
    let selectedZoom: Double
    let onSelect: (Double) -> Void
    var palette: AppPalette = AppTheme.dark.palette

    var body: some View {
        HStack(spacing: AppSpacing.gapS) {
            ForEach(zooms, id: \.self) { zoom in
                Button(action: { onSelect(zoom) }) {
                    Text(label(for: zoom))
                        .font(AppTypography.chip)
                        .foregroundStyle(isSelected(zoom) ? AppColors.mint : palette.onSurface.opacity(0.82))
                        .frame(width: AppMetrics.Camera.zoomChipWidth, height: AppMetrics.Camera.zoomChipHeight)
                        .background(palette.glassFill.opacity(0.9), in: Circle())
                        .overlay(
                            Circle().strokeBorder(
                                isSelected(zoom) ? AppColors.mint.opacity(0.72) : palette.glassBorder,
                                lineWidth: AppMetrics.borderHairline
                            )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: AppMetrics.Camera.zoomStripHeight)
    }

    private func isSelected(_ zoom: Double) -> Bool {
        abs(selectedZoom - zoom) < 0.05
    }

    private func label(for zoom: Double) -> String {
        if zoom == floor(zoom) {
            return "\(Int(zoom))x"
        }
        return String(format: "%.1fx", zoom)
    }
}

#if DEBUG
#Preview {
    ZStack {
        Color.black
        ZoomControlStrip(zooms: [0.5, 1, 2, 3], selectedZoom: 1, onSelect: { _ in })
    }
}
#endif
