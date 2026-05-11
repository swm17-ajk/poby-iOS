import Foundation
import Combine

protocol GuideRepositoryProtocol: AnyObject {
    var guidesPublisher: AnyPublisher<[Guide], Never> { get }

    @discardableResult
    func add(silhouette: GuideSilhouette, sourceImage: Data) async throws -> Guide

    func delete(id: UUID) async throws

    func thumbnailURL(for id: UUID) -> URL?
}
