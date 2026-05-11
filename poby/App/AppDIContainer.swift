import Foundation

@MainActor
final class AppDIContainer {
    static let shared = AppDIContainer()

    private lazy var cameraService = CameraService()
    private lazy var visionService = VisionService()
    private lazy var guideRepository: GuideRepositoryProtocol = {
        do {
            return try FileGuideRepository()
        } catch {
            fatalError("Failed to initialize guide repository: \(error)")
        }
    }()

    private init() {}

    func makeCameraViewModel() -> CameraViewModel {
        CameraViewModel(cameraService: cameraService)
    }

    func makeGuideCaptureViewModel() -> GuideCaptureViewModel {
        GuideCaptureViewModel(cameraService: cameraService)
    }

    func makeGuideExtractionViewModel(imageData: Data) -> GuideExtractionViewModel {
        GuideExtractionViewModel(
            imageData: imageData,
            visionService: visionService,
            guideRepository: guideRepository
        )
    }
}
