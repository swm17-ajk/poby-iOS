import SwiftUI

struct SilhouetteOverlay: View {
    let silhouette: GuideSilhouette
    var color: Color = .white
    var lineWidth: CGFloat = 2.5
    var glow: Bool = false

    var body: some View {
        Canvas { context, size in
            for contour in silhouette.contours {
                guard let first = contour.first else { continue }
                var path = Path()
                path.move(to: point(first, in: size))
                for p in contour.dropFirst() {
                    path.addLine(to: point(p, in: size))
                }
                path.closeSubpath()
                if glow {
                    context.addFilter(.shadow(color: color.opacity(0.6), radius: 6, x: 0, y: 0))
                }
                context.stroke(
                    path,
                    with: .color(color),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )
            }
        }
    }

    private func point(_ p: NormalizedPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: p.x * size.width, y: (1 - p.y) * size.height)
    }
}
