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
                Spacer(minLength: 0)
            }
        }
        .frame(height: AppMetrics.Camera.guideStripHeight)
    }
}
