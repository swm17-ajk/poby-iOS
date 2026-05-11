import SwiftUI

struct GlassChip<Content: View>: View {
    let size: CGFloat
    @ViewBuilder let content: () -> Content

    init(size: CGFloat = 36, @ViewBuilder content: @escaping () -> Content) {
        self.size = size
        self.content = content
    }

    var body: some View {
        content()
            .frame(width: size, height: size)
            .background(
                ZStack {
                    Circle().fill(.ultraThinMaterial)
                    Circle().fill(Color.white.opacity(0.10))
                }
            )
            .overlay(Circle().strokeBorder(Color.white.opacity(0.16), lineWidth: 1))
    }
}
