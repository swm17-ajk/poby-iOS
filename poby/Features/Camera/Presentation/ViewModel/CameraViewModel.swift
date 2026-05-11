import Foundation
import AVFoundation

@MainActor
final class CameraViewModel: ObservableObject {
    @Published private(set) var state: CameraViewState

    let cameraService: CameraService

    init(state: CameraViewState = .initial, cameraService: CameraService) {
        self.state = state
        self.cameraService = cameraService
    }

    var session: AVCaptureSession { cameraService.session }

    func onAppear() async {
        guard state.status == .idle || state.status == .denied else { return }
        state.status = .preparing
        do {
            try await cameraService.start()
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
            try await cameraService.capturePhoto()
            state.lastSavedAt = Date()
            state.status = .ready
        } catch {
            state.status = .failed(message: error.localizedDescription)
        }
    }
}
