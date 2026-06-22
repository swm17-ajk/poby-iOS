import SwiftUI

struct GlassChip<Content: View>: View {
    let size: CGFloat
    var palette: AppPalette
    @ViewBuilder let content: () -> Content

    init(
        size: CGFloat = 36,
        palette: AppPalette = AppTheme.dark.palette,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.size = size
        self.palette = palette
        self.content = content
    }

    var body: some View {
        content()
            .frame(width: size, height: size)
            .background(Circle().fill(palette.glassFill))
            .overlay(Circle().strokeBorder(palette.glassBorder, lineWidth: AppMetrics.borderHairline))
    }
}
