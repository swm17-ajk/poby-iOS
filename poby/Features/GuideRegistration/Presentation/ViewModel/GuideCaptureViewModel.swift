import Foundation
import AVFoundation

@MainActor
final class GuideCaptureViewModel: ObservableObject {
    @Published private(set) var state: GuideCaptureViewState
    @Published private(set) var isFlashOn: Bool
    @Published private(set) var cameraPosition: CameraPosition

    let cameraService: CameraService
    private let settingsStore: UserDefaultsAppSettingsStore
    private var settings: AppSettings

    init(
        state: GuideCaptureViewState = .initial,
        cameraService: CameraService,
        settingsStore: UserDefaultsAppSettingsStore
    ) {
        let loadedSettings = settingsStore.load()
        self.state = state
        self.cameraService = cameraService
        self.settingsStore = settingsStore
        self.settings = loadedSettings
        self.isFlashOn = loadedSettings.flashMode != .off
        self.cameraPosition = loadedSettings.cameraPosition
    }

#if DEBUG
    init(previewState: GuideCaptureViewState) {
        self.state = previewState
        self.cameraService = CameraService()
        self.settingsStore = UserDefaultsAppSettingsStore()
        self.settings = .defaults
        self.isFlashOn = settings.flashMode != .off
        self.cameraPosition = settings.cameraPosition
    }
#endif

    var session: AVCaptureSession { cameraService.session }

    func onAppear() async {
        guard state.status == .idle || state.status == .denied else { return }
        state.status = .preparing
        do {
            try await cameraService.start()
            try await cameraService.setCameraPosition(settings.cameraPosition)
            cameraService.setFlashMode(settings.flashMode)
            cameraPosition = settings.cameraPosition
            isFlashOn = settings.flashMode != .off
            state.status = .ready
        } catch let error as CameraServiceError {
            if case .cameraPermissionDenied = error {
                state.status = .denied
            } else {
                state.status = .failed(message: error.localizedDescription)
            }
        } catch {
            state.status = .failed(message: error.localizedDescription)
        }
    }

    func onDisappear() {
        cameraService.stop()
    }

    func capture() async {
        guard state.status == .ready else { return }
        state.status = .capturing
        do {
            let data = try await cameraService.capturePhoto()
            state.capturedImage = data
            state.status = .ready
        } catch {
            state.status = .failed(message: error.localizedDescription)
        }
    }

    func discardCaptured() {
        state.capturedImage = nil
    }

    func toggleFlash() {
        settings.flashMode = settings.flashMode == .off ? .on : .off
        isFlashOn = settings.flashMode != .off
        cameraService.setFlashMode(settings.flashMode)
        settingsStore.save(settings)
    }
}
