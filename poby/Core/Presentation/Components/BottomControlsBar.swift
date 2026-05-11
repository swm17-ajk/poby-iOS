import SwiftUI

struct BottomControlsBar: View {
    let onGalleryTap: () -> Void
    let onFlipTap: () -> Void

    var body: some View {
        HStack {
            controlButton(icon: "photo.on.rectangle", action: onGalleryTap)
            Spacer()
            controlButton(icon: "arrow.triangle.2.circlepath.camera", action: onFlipTap)
        }
        .padding(.horizontal, AppSpacing.groupM)
        .frame(height: AppMetrics.Camera.controlsHeight)
        .background(Color.black)
        .overlay(alignment: .top) {
            Color.white.opacity(0.06).frame(height: 0.5)
        }
    }

    private func controlButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: AppRadius.thumb))
        }
        .buttonStyle(.plain)
    }
}
