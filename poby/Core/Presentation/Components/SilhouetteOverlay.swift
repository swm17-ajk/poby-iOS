import SwiftUI

struct SilhouetteOverlay: View {
    let silhouette: GuideSilhouette
    var color: Color = .white
    var lineWidth: CGFloat = 2.5
    var glow: Bool = false

    var body: some View {
        Canvas { context, size in
            if glow {
                context.addFilter(.shadow(color: color.opacity(0.6), radius: 6, x: 0, y: 0))
            }
            for contour in silhouette.contours {
                let path = closedCurvePath(contour, in: size)
                context.stroke(
                    path,
                    with: .color(color),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )
            }

            if let faceContour = silhouette.faceContour {
                let path = openCurvePath(faceContour, in: size)
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

    private func closedCurvePath(_ points: [NormalizedPoint], in size: CGSize) -> Path {
        guard points.count > 2 else { return openCurvePath(points, in: size) }
        let cgPoints = points.map { point($0, in: size) }
        var path = Path()
        let last = cgPoints[cgPoints.count - 1]
        let first = cgPoints[0]
        path.move(to: midpoint(last, first))
        for index in cgPoints.indices {
            let current = cgPoints[index]
            let next = cgPoints[(index + 1) % cgPoints.count]
            path.addQuadCurve(to: midpoint(current, next), control: current)
        }
        path.closeSubpath()
        return path
    }

    private func openCurvePath(_ points: [NormalizedPoint], in size: CGSize) -> Path {
        guard let first = points.first else { return Path() }
        let cgPoints = points.map { point($0, in: size) }
        guard cgPoints.count > 2 else {
            var path = Path()
            path.move(to: point(first, in: size))
            for p in points.dropFirst() {
                path.addLine(to: point(p, in: size))
            }
            return path
        }
        var path = Path()
        path.move(to: cgPoints[0])
        for index in 1..<(cgPoints.count - 1) {
            path.addQuadCurve(to: midpoint(cgPoints[index], cgPoints[index + 1]), control: cgPoints[index])
        }
        if let last = cgPoints.last {
            path.addLine(to: last)
        }
        return path
    }

    private func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }
}
