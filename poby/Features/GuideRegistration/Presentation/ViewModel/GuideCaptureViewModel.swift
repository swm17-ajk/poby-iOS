import Foundation
import AVFoundation

@MainActor
final class GuideCaptureViewModel: ObservableObject {
    @Published private(set) var state: GuideCaptureViewState

    let cameraService: CameraService

    init(state: GuideCaptureViewState = .initial, cameraService: CameraService) {
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
}
