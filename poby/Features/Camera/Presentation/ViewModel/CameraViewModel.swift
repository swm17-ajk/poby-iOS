import Foundation
import AVFoundation
import Combine
import CoreGraphics
import CoreVideo

@MainActor
final class CameraViewModel: ObservableObject {
    @Published var state: CameraViewState
    @Published private(set) var guides: [Guide] = []
    @Published private(set) var selectedGuide: Guide?
    @Published private(set) var isMatched: Bool = false
    @Published var guideToDelete: Guide?

    let cameraService: CameraService
    private let guideRepository: GuideRepositoryProtocol
    private let matchEngine: MatchEngine
    private var cancellables = Set<AnyCancellable>()
    private var seenGuideIds: Set<UUID> = []

    init(
        state: CameraViewState = .initial,
        cameraService: CameraService,
        guideRepository: GuideRepositoryProtocol,
        visionService: VisionService
    ) {
        self.state = state
        self.cameraService = cameraService
        self.guideRepository = guideRepository
        self.matchEngine = MatchEngine(visionService: visionService)

        matchEngine.onResult = { [weak self] matched in
            Task { @MainActor [weak self] in
                self?.isMatched = matched
            }
        }
        cameraService.onVideoFrame = { [weak self] pixelBuffer in
            self?.matchEngine.process(pixelBuffer)
        }

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

    func presentAddGuideSheet() { state.isAddGuideSheetPresented = true }
    func presentPhotoPicker() {
        state.isAddGuideSheetPresented = false
        state.isPhotoPickerPresented = true
    }

    func selectGuide(_ guide: Guide) {
        selectedGuide = guide
        isMatched = false
        matchEngine.setGuide(guide)
    }

    func requestDelete(_ guide: Guide) { guideToDelete = guide }
    func cancelDelete() { guideToDelete = nil }

    func confirmDelete() async {
        guard let guide = guideToDelete else { return }
        guideToDelete = nil
        do {
            try await guideRepository.delete(id: guide.id)
        } catch {
            state.status = .failed(message: error.localizedDescription)
        }
    }

    func cycleAspectRatio() { state.aspectRatio = state.aspectRatio.next() }
    func toggleFlash() { state.isFlashOn.toggle() }

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
                    self.isMatched = false
                    self.matchEngine.setGuide(newest)
                } else if let current = self.selectedGuide,
                          !currentIds.contains(current.id) {
                    let fallback = guides.max(by: { $0.createdAt < $1.createdAt })
                    self.selectedGuide = fallback
                    self.isMatched = false
                    self.matchEngine.setGuide(fallback)
                }
                seenGuideIds = currentIds
            }
            .store(in: &cancellables)
    }
}

// MARK: - Match Engine

private final class MatchEngine: @unchecked Sendable {
    private let visionService: VisionService
    private let queue = DispatchQueue(label: "yuna.poby.matching", qos: .userInitiated)
    private let lock = NSLock()
    private var lastTime: CFAbsoluteTime = 0
    private var currentGuide: Guide?
    private let minInterval: CFAbsoluteTime = 0.25
    private let threshold: Double = 0.55

    var onResult: (@Sendable (Bool) -> Void)?

    init(visionService: VisionService) {
        self.visionService = visionService
    }

    func setGuide(_ guide: Guide?) {
        lock.lock()
        currentGuide = guide
        lock.unlock()
    }

    func process(_ pixelBuffer: CVPixelBuffer) {
        queue.async { [weak self] in
            self?.run(pixelBuffer)
        }
    }

    private func run(_ pixelBuffer: CVPixelBuffer) {
        lock.lock()
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastTime >= minInterval else { lock.unlock(); return }
        lastTime = now
        let guide = currentGuide
        lock.unlock()

        guard let guide else { return }

        guard let cameraBox = visionService.personBoundingRect(in: pixelBuffer) else {
            onResult?(false)
            return
        }

        let width = Double(CVPixelBufferGetWidth(pixelBuffer))
        let height = Double(CVPixelBufferGetHeight(pixelBuffer))
        let cameraAspect = width / height
        let guideAspect = guide.sourceAspectRatio ?? cameraAspect

        let transformed = Self.transformGuideBox(
            guide.silhouette.boundingBox,
            guideAspect: guideAspect,
            cameraAspect: cameraAspect
        )
        let iou = Self.iou(transformed, cameraBox)
        onResult?(iou >= threshold)
    }

    private static func transformGuideBox(
        _ box: CGRect,
        guideAspect: Double,
        cameraAspect: Double
    ) -> CGRect {
        let fitRect: CGRect
        if guideAspect > cameraAspect {
            let h = cameraAspect / guideAspect
            fitRect = CGRect(x: 0, y: (1 - h) / 2, width: 1, height: h)
        } else {
            let w = guideAspect / cameraAspect
            fitRect = CGRect(x: (1 - w) / 2, y: 0, width: w, height: 1)
        }
        return CGRect(
            x: fitRect.minX + box.minX * fitRect.width,
            y: fitRect.minY + box.minY * fitRect.height,
            width: box.width * fitRect.width,
            height: box.height * fitRect.height
        )
    }

    private static func iou(_ a: CGRect, _ b: CGRect) -> Double {
        let inter = a.intersection(b)
        if inter.isNull || inter.isEmpty { return 0 }
        let interArea = Double(inter.width * inter.height)
        let unionArea = Double(a.width * a.height) + Double(b.width * b.height) - interArea
        return unionArea <= 0 ? 0 : interArea / unionArea
    }
}
