import Foundation

enum GuideExtractionViewState: Equatable {
    case loading
    case success(silhouette: GuideSilhouette)
    case failure(message: String)
}
