import SwiftUI

struct GuideListStrip: View {
    let guides: [Guide]
    let selectedGuideId: UUID?
    let thumbnailURL: (UUID) -> URL?
    var palette: AppPalette = AppTheme.dark.palette
    let onTapGuide: (Guide) -> Void
    let onLongPressGuide: (Guide) -> Void
    let onTapPlus: () -> Void

    var body: some View {
        GeometryReader { geo in
            let stripWidth = geo.size.width * AppMetrics.Camera.guideStripWidthFraction
            HStack {
                Spacer(minLength: 0)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.gapXS) {
                        ForEach(guides) { guide in
                            GuideThumb(
                                guide: guide,
                                thumbnailURL: thumbnailURL(guide.id),
                                isActive: selectedGuideId == guide.id,
                                palette: palette,
                                onTap: { onTapGuide(guide) },
                                onLongPress: { onLongPressGuide(guide) }
                            )
                        }
                        PlusThumb(pulse: guides.isEmpty, palette: palette, onTap: onTapPlus)
                    }
                    .frame(minWidth: stripWidth, alignment: .center)
                }
                .frame(width: stripWidth)
                .mask(edgeFadeMask)
                .transaction { transaction in
                    transaction.animation = nil
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: AppMetrics.Camera.guideStripHeight)
    }

    private var edgeFadeMask: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.1),
                .init(color: .black, location: 0.9),
                .init(color: .clear, location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
