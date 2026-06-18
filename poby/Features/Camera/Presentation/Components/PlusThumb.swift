import SwiftUI

struct PlusThumb: View {
    let pulse: Bool
    var palette: AppPalette = AppTheme.dark.palette
    let onTap: () -> Void

    @State private var pulsing = false

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.thumb)
                    .fill(palette.glassFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.thumb)
                            .strokeBorder(palette.glassBorder, lineWidth: AppMetrics.borderHairline)
                    )
                    .frame(width: AppMetrics.Camera.guideThumbSize, height: AppMetrics.Camera.guideThumbSize)

                Image(systemName: "plus")
                    .font(.system(size: AppMetrics.iconM + 4, weight: .semibold))
                    .foregroundStyle(palette.onSurface)
            }
            .scaleEffect(pulse && pulsing ? 1.04 : 1.0)
            .shadow(
                color: pulse && pulsing ? palette.onSurface.opacity(0.18) : .clear,
                radius: 8
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            guard pulse else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
        .onChange(of: pulse) { _, newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    pulsing = true
                }
            } else {
                pulsing = false
            }
        }
    }
}
