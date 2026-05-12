import Foundation
import CoreGraphics

struct Guide: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let createdAt: Date
    let silhouette: GuideSilhouette
    let sourceAspectRatio: Double?
}

struct GuideSilhouette: Codable, Equatable, Hashable {
    let contours: [[NormalizedPoint]]
    /// 관자놀이 → 턱 → 관자놀이 라인. 얼굴 미검출 시 nil.
    let faceContour: [NormalizedPoint]?

    init(contours: [[NormalizedPoint]], faceContour: [NormalizedPoint]? = nil) {
        self.contours = contours
        self.faceContour = faceContour
    }

    var boundingBox: CGRect {
        var minX = 1.0, minY = 1.0, maxX = 0.0, maxY = 0.0
        var anyPoint = false
        for contour in contours {
            for p in contour {
                if p.x < minX { minX = p.x }
                if p.x > maxX { maxX = p.x }
                if p.y < minY { minY = p.y }
                if p.y > maxY { maxY = p.y }
                anyPoint = true
            }
        }
        guard anyPoint else { return .zero }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

struct NormalizedPoint: Codable, Equatable, Hashable {
    let x: Double
    let y: Double
}
