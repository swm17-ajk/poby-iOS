import Foundation
import AVFoundation
import Combine
import CoreGraphics
import CoreVideo
import SwiftUI
import UIKit

@MainActor
final class CameraViewModel: ObservableObject {
    @Published var state: CameraViewState
    @Published private(set) var guides: [Guide] = []
    @Published private(set) var selectedGuide: Guide?
    @Published private(set) var isMatched: Bool = false
    @Published private(set) var availableZooms: [Double] = [1.0]
    @Published private(set) var selectedZoom: Double = 1.0
    @Published private(set) var guideColorPreference: GuideColorPreference = .white
    @Published var guideToDelete: Guide?

    let cameraService: CameraService
    private let guideRepository: GuideRepositoryProtocol
    private let settingsStore: UserDefaultsAppSettingsStore
    private let matchEngine: MatchEngine
    private var cancellables = Set<AnyCancellable>()
    private var seenGuideIds: Set<UUID> = []
    private var settings: AppSettings

    init(
        state: CameraViewState = .initial,
        cameraService: CameraService,
        guideRepository: GuideRepositoryProtocol,
        visionService: VisionService,
        settingsStore: UserDefaultsAppSettingsStore
    ) {
        let loadedSettings = settingsStore.load()
        var initialState = state
        initialState.aspectRatio = loadedSettings.selectedAspectRatio
        initialState.isFlashOn = loadedSettings.flashMode != .off
        initialState.selectedTheme = loadedSettings.selectedTheme
        self.state = initialState
        self.cameraService = cameraService
        self.guideRepository = guideRepository
        self.settingsStore = settingsStore
        self.matchEngine = MatchEngine(visionService: visionService)
        self.settings = loadedSettings
        self.selectedZoom = loadedSettings.selectedZoom
        self.guideColorPreference = loadedSettings.guideColor

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

#if DEBUG
    init(
        previewState: CameraViewState = CameraViewState(status: .ready),
        previewGuides: [Guide] = [],
        previewSelectedGuide: Guide? = nil,
        previewIsMatched: Bool = false
    ) {
        self.state = previewState
        self.cameraService = CameraService()
        self.settingsStore = UserDefaultsAppSettingsStore()
        self.matchEngine = MatchEngine(visionService: VisionService())
        self.settings = .defaults
        self.guideColorPreference = settings.guideColor
        do {
            self.guideRepository = try FileGuideRepository()
        } catch {
            fatalError("Preview repo init failed: \(error)")
        }
        self.guides = previewGuides
        self.selectedGuide = previewSelectedGuide
        self.isMatched = previewIsMatched
    }
#endif

    var session: AVCaptureSession { cameraService.session }
    var currentGuideColor: Color {
        guideColorPreference == .white ? .white : AppColors.mint
    }
    var palette: AppPalette { state.selectedTheme.palette }

    func onAppear() async {
        guard state.status == .idle || state.status == .denied else { return }
        state.status = .preparing
        do {
            try await cameraService.start()
            try await cameraService.setCameraPosition(settings.cameraPosition)
            cameraService.setFlashMode(settings.flashMode)
            availableZooms = await cameraService.supportedZoomFactors()
            selectedZoom = await cameraService.setZoomFactor(settings.selectedZoom)
            persist { $0.selectedZoom = selectedZoom }
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
        guard state.pendingCapture == nil else { return }
        state.status = .capturing
        do {
            let data = try await cameraService.capturePhoto()
            state.pendingCapture = PendingCapture(
                imageData: normalizedCaptureData(data),
                aspectRatio: state.aspectRatio,
                capturedGuide: selectedGuide,
                showGuide: selectedGuide != nil
            )
            state.status = .ready
        } catch {
            state.status = .failed(message: error.localizedDescription)
        }
    }

    func confirmSaveCapture() async {
        guard let pending = state.pendingCapture else { return }
        state.pendingCapture = nil
        do {
            try await cameraService.saveToPhotoLibrary(pending.imageData)
            state.lastSavedAt = Date()
        } catch {
            state.status = .failed(message: error.localizedDescription)
        }
    }

    func discardCapture() {
        state.pendingCapture = nil
    }

    func togglePendingGuide() {
        guard var pending = state.pendingCapture else { return }
        pending.showGuide.toggle()
        state.pendingCapture = pending
    }

    func presentAddGuideSheet() { state.isAddGuideSheetPresented = true }
    func presentPhotoPicker() {
        state.isAddGuideSheetPresented = false
        state.isPhotoPickerPresented = true
    }

    func selectGuide(_ guide: Guide) {
        if selectedGuide?.id == guide.id {
            selectedGuide = nil
            isMatched = false
            matchEngine.setGuide(nil)
            persist { $0.selectedGuideId = nil }
            return
        }
        selectedGuide = guide
        isMatched = false
        matchEngine.setGuide(guide)
        persist { $0.selectedGuideId = guide.id }
    }

    func requestDelete(_ guide: Guide) { guideToDelete = guide }
    func cancelDelete() { guideToDelete = nil }

    func confirmDelete(_ guide: Guide) async {
        guideToDelete = nil
        do {
            try await guideRepository.delete(id: guide.id)
        } catch {
            state.status = .failed(message: error.localizedDescription)
        }
    }

    func selectAspectRatio(_ ratio: CameraAspectRatio) {
        state.aspectRatio = ratio
        persist { $0.selectedAspectRatio = state.aspectRatio }
    }

    func selectTheme(_ theme: AppTheme) {
        state.selectedTheme = theme
        persist { $0.selectedTheme = theme }
    }

    func cycleFlashMode() {
        settings.flashMode = settings.flashMode.next()
        state.isFlashOn = settings.flashMode != .off
        cameraService.setFlashMode(settings.flashMode)
        settingsStore.save(settings)
    }

    func toggleGuideColor() {
        guideColorPreference = guideColorPreference.toggled()
        persist { $0.guideColor = guideColorPreference }
    }

    func selectZoom(_ zoom: Double) {
        Task {
            let applied = await cameraService.setZoomFactor(zoom)
            selectedZoom = applied
            persist { $0.selectedZoom = applied }
        }
    }

    func switchCamera() {
        Task {
            do {
                let position = try await cameraService.switchCamera()
                availableZooms = await cameraService.supportedZoomFactors()
                selectedZoom = await cameraService.setZoomFactor(1.0)
                persist {
                    $0.cameraPosition = position
                    $0.selectedZoom = selectedZoom
                }
            } catch {
                state.status = .failed(message: error.localizedDescription)
            }
        }
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
                    self.isMatched = false
                    self.matchEngine.setGuide(newest)
                    self.persist { $0.selectedGuideId = newest.id }
                } else if let current = self.selectedGuide,
                          !currentIds.contains(current.id) {
                    let fallback = guides.max(by: { $0.createdAt < $1.createdAt })
                    self.selectedGuide = fallback
                    self.isMatched = false
                    self.matchEngine.setGuide(fallback)
                    self.persist { $0.selectedGuideId = fallback?.id }
                } else if self.selectedGuide == nil,
                          let selectedId = self.settings.selectedGuideId,
                          let restored = guides.first(where: { $0.id == selectedId }) {
                    self.selectedGuide = restored
                    self.isMatched = false
                    self.matchEngine.setGuide(restored)
                }
                seenGuideIds = currentIds
            }
            .store(in: &cancellables)
    }

    private func persist(_ update: (inout AppSettings) -> Void) {
        update(&settings)
        settingsStore.save(settings)
    }

    private func normalizedCaptureData(_ data: Data) -> Data {
        guard let image = UIImage(data: data),
              let normalized = image.normalizedForPobyCapture(),
              let cgImage = normalized.cgImage else {
            return data
        }
        let targetAspect = state.aspectRatio.value
        let imageAspect = CGFloat(cgImage.width) / CGFloat(cgImage.height)
        let rect: CGRect
        if imageAspect > targetAspect {
            let width = CGFloat(cgImage.height) * targetAspect
            rect = CGRect(
                x: (CGFloat(cgImage.width) - width) / 2,
                y: 0,
                width: width,
                height: CGFloat(cgImage.height)
            )
        } else {
            let height = CGFloat(cgImage.width) / targetAspect
            rect = CGRect(
                x: 0,
                y: (CGFloat(cgImage.height) - height) / 2,
                width: CGFloat(cgImage.width),
                height: height
            )
        }
        guard let cropped = cgImage.cropping(to: rect) else { return data }
        return UIImage(cgImage: cropped, scale: normalized.scale, orientation: .up)
            .jpegData(compressionQuality: 0.95) ?? data
    }
}

private extension UIImage {
    func normalizedForPobyCapture() -> UIImage? {
        if imageOrientation == .up {
            return self
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
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
