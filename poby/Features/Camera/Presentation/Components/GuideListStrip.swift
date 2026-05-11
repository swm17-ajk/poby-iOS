import SwiftUI

struct GuideListStrip: View {
    let guides: [Guide]
    let selectedGuideId: UUID?
    let thumbnailURL: (UUID) -> URL?
    let onTapGuide: (Guide) -> Void
    let onLongPressGuide: (Guide) -> Void
    let onTapPlus: () -> Void

    var body: some View {
        GeometryReader { geo in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.gapXS) {
                    ForEach(guides) { guide in
                        GuideThumb(
                            guide: guide,
                            thumbnailURL: thumbnailURL(guide.id),
                            isActive: selectedGuideId == guide.id,
                            onTap: { onTapGuide(guide) },
                            onLongPress: { onLongPressGuide(guide) }
                        )
                    }
                    PlusThumb(pulse: guides.isEmpty, onTap: onTapPlus)
                }
                .padding(.horizontal, AppSpacing.edge)
                .frame(minWidth: geo.size.width, alignment: .center)
            }
        }
        .frame(height: 78)
    }
}
