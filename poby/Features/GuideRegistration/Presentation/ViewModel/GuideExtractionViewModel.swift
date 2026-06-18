import Foundation

@MainActor
final class GuideExtractionViewModel: ObservableObject {
    @Published private(set) var state: GuideExtractionViewState = .loading

    let sourceImageData: Data
    private let visionService: VisionService
    private let guideRepository: GuideRepositoryProtocol
    private let analytics: AnalyticsService
    private var isPreview = false

    init(
        imageData: Data,
        visionService: VisionService,
        guideRepository: GuideRepositoryProtocol,
        analytics: AnalyticsService
    ) {
        self.sourceImageData = imageData
        self.visionService = visionService
        self.guideRepository = guideRepository
        self.analytics = analytics
    }

#if DEBUG
    init(previewState: GuideExtractionViewState, imageData: Data) {
        self.state = previewState
        self.sourceImageData = imageData
        self.visionService = VisionService()
        self.analytics = AmplitudeAnalyticsService()
        do {
            self.guideRepository = try FileGuideRepository()
        } catch {
            fatalError("Preview repo init failed: \(error)")
        }
        self.isPreview = true
    }
#endif

    var isDoneEnabled: Bool {
        if case .success = state { return true }
        return false
    }

    func extract() async {
        if isPreview { return }
        guard case .loading = state else { return }
        logViewedStatus()
        do {
            let silhouette = try await visionService.extractSilhouette(from: sourceImageData)
            state = .success(silhouette: silhouette)
            logViewedStatus()
        } catch let error as VisionServiceError {
            state = .failure(message: error.localizedDescription)
            logViewedStatus()
        } catch {
            state = .failure(message: error.localizedDescription)
            logViewedStatus()
        }
    }

    func save() async throws -> Guide {
        guard case let .success(silhouette) = state else {
            throw VisionServiceError.noPersonFound
        }
        let guide = try await guideRepository.add(silhouette: silhouette, sourceImage: sourceImageData)
        analytics.log(AnalyticsEvent.guideSaved)
        return guide
    }

    func cancel() {
        analytics.log(
            AnalyticsEvent.guideExtractionCancelled,
            properties: ["status": state.analyticsStatus]
        )
    }

    private func logViewedStatus() {
        analytics.log(
            AnalyticsEvent.guideExtractionViewed,
            properties: ["status": state.analyticsStatus]
        )
    }
}

private extension GuideExtractionViewState {
    var analyticsStatus: String {
        switch self {
        case .loading:
            return "loading"
        case .success:
            return "success"
        case .failure:
            return "failure"
        }
    }
}
