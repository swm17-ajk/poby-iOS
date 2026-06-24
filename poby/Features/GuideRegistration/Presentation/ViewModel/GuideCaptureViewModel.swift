import Foundation
import AVFoundation

@MainActor
final class GuideCaptureViewModel: ObservableObject {
    @Published private(set) var state: GuideCaptureViewState
    @Published private(set) var isFlashOn: Bool
    @Published private(set) var cameraPosition: CameraPosition
    @Published private(set) var selectedZoom: Double

    let cameraService: CameraService
    private let settingsStore: UserDefaultsAppSettingsStore
    private let analytics: AnalyticsService
    private var settings: AppSettings
    private var hasActiveCameraSession = false
    private var zoomUpdateTask: Task<Void, Never>?
    private var pendingZoomUpdate: (zoom: Double, persistsSelection: Bool)?

    init(
        state: GuideCaptureViewState = .initial,
        cameraService: CameraService,
        settingsStore: UserDefaultsAppSettingsStore,
        analytics: AnalyticsService
    ) {
        let loadedSettings = settingsStore.load()
        self.state = state
        self.cameraService = cameraService
        self.settingsStore = settingsStore
        self.analytics = analytics
        self.settings = loadedSettings
        self.isFlashOn = loadedSettings.flashMode != .off
        self.cameraPosition = loadedSettings.cameraPosition
        self.selectedZoom = loadedSettings.selectedZoom
    }

#if DEBUG
    init(previewState: GuideCaptureViewState) {
        self.state = previewState
        self.cameraService = CameraService()
        self.settingsStore = UserDefaultsAppSettingsStore()
        self.analytics = AmplitudeAnalyticsService()
        self.settings = .defaults
        self.isFlashOn = settings.flashMode != .off
        self.cameraPosition = settings.cameraPosition
        self.selectedZoom = settings.selectedZoom
    }
#endif

    var session: AVCaptureSession { cameraService.session }

    func onAppear() async {
        guard !hasActiveCameraSession else { return }
        guard state.status == .idle || state.status == .denied || state.status == .ready else { return }
        let wasReady = state.status == .ready
        if !wasReady {
            analytics.log(AnalyticsEvent.guideCaptureViewed)
            state.status = .preparing
        }
        do {
            try await cameraService.start()
            hasActiveCameraSession = true
            try await cameraService.setCameraPosition(settings.cameraPosition)
            cameraService.setFlashMode(settings.flashMode)
            selectedZoom = await cameraService.setZoomFactor(settings.selectedZoom)
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
        guard hasActiveCameraSession else { return }
        hasActiveCameraSession = false
        cameraService.stop()
    }

    func capture() async {
        guard state.status == .ready else { return }
        analytics.log(AnalyticsEvent.guideCaptureShutterTapped)
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
        analytics.log(
            AnalyticsEvent.guideCaptureAction,
            properties: ["action": "retake"]
        )
        state.capturedImage = nil
    }

    func confirmCaptured() {
        analytics.log(
            AnalyticsEvent.guideCaptureAction,
            properties: ["action": "confirm"]
        )
    }

    func toggleFlash() {
        settings.flashMode = settings.flashMode == .off ? .on : .off
        isFlashOn = settings.flashMode != .off
        cameraService.setFlashMode(settings.flashMode)
        settingsStore.save(settings)
    }

    func pinchZoom(to zoom: Double, isFinal: Bool) {
        if zoomUpdateTask != nil {
            pendingZoomUpdate = (
                zoom: zoom,
                persistsSelection: pendingZoomUpdate?.persistsSelection == true || isFinal
            )
            return
        }
        zoomUpdateTask = Task { [weak self] in
            await self?.runZoomUpdates(zoom: zoom, persistsSelection: isFinal)
        }
    }

    private func runZoomUpdates(zoom: Double, persistsSelection: Bool) async {
        var nextZoom = zoom
        var shouldPersist = persistsSelection
        while true {
            let applied = await cameraService.setZoomFactor(nextZoom)
            selectedZoom = applied
            if shouldPersist {
                settings.selectedZoom = applied
                settingsStore.save(settings)
                analytics.log(
                    AnalyticsEvent.zoomChanged,
                    properties: [
                        "zoom": applied,
                        "facing": cameraPosition.rawValue
                    ]
                )
            }
            if let pendingZoomUpdate {
                self.pendingZoomUpdate = nil
                nextZoom = pendingZoomUpdate.zoom
                shouldPersist = pendingZoomUpdate.persistsSelection
                continue
            }
            zoomUpdateTask = nil
            return
        }
    }
}
