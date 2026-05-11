import Foundation

struct Guide: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let createdAt: Date
    let silhouette: GuideSilhouette
    let sourceAspectRatio: Double?
}

struct GuideSilhouette: Codable, Equatable, Hashable {
    let contours: [[NormalizedPoint]]
}

struct NormalizedPoint: Codable, Equatable, Hashable {
    let x: Double
    let y: Double
}
