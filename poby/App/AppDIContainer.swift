import Foundation

@MainActor
final class AppDIContainer {
    static let shared = AppDIContainer()

    private lazy var cameraService = CameraService()

    private init() {}

    func makeCameraViewModel() -> CameraViewModel {
        CameraViewModel(cameraService: cameraService)
    }

    func makeGuideRegistrationViewModel() -> GuideRegistrationViewModel {
        GuideRegistrationViewModel()
    }
}
