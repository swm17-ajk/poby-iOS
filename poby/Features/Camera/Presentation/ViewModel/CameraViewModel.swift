import Foundation
import AVFoundation
import Combine

@MainActor
final class CameraViewModel: ObservableObject {
    @Published var state: CameraViewState
    @Published private(set) var guides: [Guide] = []
    @Published private(set) var selectedGuide: Guide?
    @Published var guideToDelete: Guide?

    let cameraService: CameraService
    private let guideRepository: GuideRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()
    private var seenGuideIds: Set<UUID> = []

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

    func selectGuide(_ guide: Guide) {
        selectedGuide = guide
    }

    func requestDelete(_ guide: Guide) {
        guideToDelete = guide
    }

    func cancelDelete() {
        guideToDelete = nil
    }

    func confirmDelete() async {
        guard let guide = guideToDelete else { return }
        guideToDelete = nil
        do {
            try await guideRepository.delete(id: guide.id)
        } catch {
            state.status = .failed(message: error.localizedDescription)
        }
    }

    func cycleAspectRatio() {
        state.aspectRatio = state.aspectRatio.next()
    }

    func toggleFlash() {
        state.isFlashOn.toggle()
    }

    func thumbnailURL(for id: UUID) -> URL? {
        guideRepository.thumbnailURL(for: id)
    }

    private func observeGuides() {
        guideRepository.guidesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] guides in
                guard let self else { return }
                let currentIds = Set(guides.map(\.id))
                let newIds = currentIds.subtracting(seenGuideIds)

                self.guides = guides.sorted(by: { $0.createdAt > $1.createdAt })

                if let newest = guides
                    .filter({ newIds.contains($0.id) })
                    .max(by: { $0.createdAt < $1.createdAt }) {
                    self.selectedGuide = newest
                } else if let current = self.selectedGuide,
                          !currentIds.contains(current.id) {
                    self.selectedGuide = guides.max(by: { $0.createdAt < $1.createdAt })
                }

                seenGuideIds = currentIds
            }
            .store(in: &cancellables)
    }
}
