import Foundation

@MainActor
final class AppDIContainer {
    static let shared = AppDIContainer()

    private lazy var cameraService = CameraService()
    private lazy var visionService = VisionService()
    private lazy var analyticsService: AnalyticsService = AmplitudeAnalyticsService()
    private lazy var settingsStore = UserDefaultsAppSettingsStore()
    private lazy var guideRepository: GuideRepositoryProtocol = {
        do {
            return try FileGuideRepository()
        } catch {
            fatalError("Failed to initialize guide repository: \(error)")
        }
    }()

    private init() {}

    func makeCameraViewModel() -> CameraViewModel {
        CameraViewModel(
            cameraService: cameraService,
            guideRepository: guideRepository,
            visionService: visionService,
            settingsStore: settingsStore,
            analytics: analyticsService
        )
    }

    func makeGuideCaptureViewModel() -> GuideCaptureViewModel {
        GuideCaptureViewModel(
            cameraService: cameraService,
            settingsStore: settingsStore,
            analytics: analyticsService
        )
    }

    func makeGuideExtractionViewModel(imageData: Data) -> GuideExtractionViewModel {
        GuideExtractionViewModel(
            imageData: imageData,
            visionService: visionService,
            guideRepository: guideRepository,
            analytics: analyticsService
        )
    }

    func makeSettingsStore() -> UserDefaultsAppSettingsStore {
        settingsStore
    }

    func makeAnalyticsService() -> AnalyticsService {
        analyticsService
    }
}
