import SwiftUI

struct GuideThumb: View {
    let guide: Guide
    let thumbnailURL: URL?
    let isActive: Bool
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
                        Color.white.opacity(0.10)
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.thumb))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.thumb)
                        .strokeBorder(
                            isActive ? AppColors.mint : Color.white.opacity(0.28),
                            lineWidth: isActive ? 2.5 : 1
                        )
                )
                .shadow(color: isActive ? AppColors.mint.opacity(0.45) : .clear, radius: 8)

                if isActive {
                    ZStack {
                        Circle()
                            .fill(AppColors.mint)
                            .frame(width: 18, height: 18)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
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
