import SwiftUI

struct BottomControlsBar: View {
    let onGalleryTap: () -> Void
    let onFlipTap: (() -> Void)?
    var palette: AppPalette = AppTheme.dark.palette
    var contentRotation: Angle = .zero

    var body: some View {
        HStack {
            controlButton(icon: "photo.on.rectangle", action: onGalleryTap)
            Spacer()
            if let onFlipTap {
                controlButton(icon: "arrow.triangle.2.circlepath.camera", action: onFlipTap)
            }
        }
        .padding(.horizontal, AppSpacing.groupM)
        .frame(height: AppMetrics.Camera.controlsHeight)
        .background(palette.surface)
        .overlay(alignment: .top) {
            palette.divider.opacity(0.35).frame(height: AppMetrics.borderHairline)
        }
    }

    private func controlButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: AppMetrics.iconM, weight: .medium))
                .foregroundStyle(palette.onSurface)
                .rotationEffect(contentRotation)
                .frame(width: AppMetrics.iconButtonLarge, height: AppMetrics.iconButtonLarge)
                .background(palette.glassFill, in: Circle())
        }
        .buttonStyle(.plain)
    }
}
