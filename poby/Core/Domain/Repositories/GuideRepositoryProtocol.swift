import Foundation
import Combine

protocol GuideRepositoryProtocol: AnyObject {
    var guidesPublisher: AnyPublisher<[Guide], Never> { get }

    @discardableResult
    func add(silhouette: GuideSilhouette, sourceImage: Data) async throws -> Guide
}
