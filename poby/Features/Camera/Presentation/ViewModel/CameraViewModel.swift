import Foundation
import AVFoundation
import Combine

@MainActor
final class CameraViewModel: ObservableObject {
    @Published var state: CameraViewState
    @Published private(set) var selectedGuide: Guide?

    let cameraService: CameraService
    private let guideRepository: GuideRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()

    init(
        state: CameraViewState = .initial,
        cameraService: CameraService,
        guideRepository: GuideRepositoryProtocol
    ) {
        self.state = state
        self.cameraService = cameraService
        self.guideRepository = guideRepository
        observeGuides()
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
            try await cameraService.saveToPhotoLibrary(data)
            state.lastSavedAt = Date()
            state.status = .ready
        } catch {
            state.status = .failed(message: error.localizedDescription)
        }
    }

    func presentAddGuideSheet() {
        state.isAddGuideSheetPresented = true
    }

    func presentPhotoPicker() {
        state.isAddGuideSheetPresented = false
        state.isPhotoPickerPresented = true
    }

    private func observeGuides() {
        guideRepository.guidesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] guides in
                self?.selectedGuide = guides.max(by: { $0.createdAt < $1.createdAt })
            }
            .store(in: &cancellables)
    }
}
