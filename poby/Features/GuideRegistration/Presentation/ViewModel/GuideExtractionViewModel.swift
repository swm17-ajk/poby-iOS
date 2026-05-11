import Foundation

@MainActor
final class GuideExtractionViewModel: ObservableObject {
    @Published private(set) var state: GuideExtractionViewState = .loading

    let sourceImageData: Data
    private let visionService: VisionService
    private let guideRepository: GuideRepositoryProtocol

    init(
        imageData: Data,
        visionService: VisionService,
        guideRepository: GuideRepositoryProtocol
    ) {
        self.sourceImageData = imageData
        self.visionService = visionService
        self.guideRepository = guideRepository
    }

    var isDoneEnabled: Bool {
        if case .success = state { return true }
        return false
    }

    func extract() async {
        state = .loading
        do {
            let silhouette = try await visionService.extractSilhouette(from: sourceImageData)
            state = .success(silhouette: silhouette)
        } catch let error as VisionServiceError {
            state = .failure(message: error.localizedDescription)
        } catch {
            state = .failure(message: error.localizedDescription)
        }
    }

    func save() async throws -> Guide {
        guard case let .success(silhouette) = state else {
            throw VisionServiceError.noPersonFound
        }
        return try await guideRepository.add(silhouette: silhouette, sourceImage: sourceImageData)
    }
}
