import SwiftUI

struct GuideThumb: View {
    let guide: Guide
    let thumbnailURL: URL?
    let isActive: Bool
    var palette: AppPalette = AppTheme.dark.palette
    let onTap: () -> Void
    let onLongPress: () -> Void

    @State private var image: UIImage?

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        palette.glassFill
                    }
                }
                .frame(width: AppMetrics.Camera.guideThumbSize, height: AppMetrics.Camera.guideThumbSize)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.thumb))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.thumb)
                        .strokeBorder(
                            isActive ? AppColors.mint : palette.glassBorder,
                            lineWidth: isActive ? AppMetrics.borderEmphasis : AppMetrics.borderHairline
                        )
                )
                .shadow(color: isActive ? AppColors.mint.opacity(0.45) : .clear, radius: 8)

                if isActive {
                    ZStack {
                        Circle()
                            .fill(AppColors.mint)
                            .frame(width: AppMetrics.iconM, height: AppMetrics.iconM)
                        Image(systemName: "checkmark")
                            .font(.system(size: AppMetrics.iconXS, weight: .bold))
                            .foregroundStyle(AppColors.mintDeep)
                    }
                    .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5).onEnded { _ in onLongPress() }
        )
        .onAppear { loadImage() }
        .onChange(of: thumbnailURL) { _, _ in loadImage() }
    }

    private func loadImage() {
        guard let url = thumbnailURL else { image = nil; return }
        image = UIImage(contentsOfFile: url.path)
    }
}
