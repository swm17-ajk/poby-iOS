import AVFoundation
import Photos
import UIKit

enum CameraServiceError: LocalizedError {
    case cameraPermissionDenied
    case photoLibraryPermissionDenied
    case cameraUnavailableOnMac
    case setupFailed(String)
    case captureFailed(String)

    var errorDescription: String? {
        switch self {
        case .cameraPermissionDenied:        return "카메라 권한이 필요해요. 설정에서 허용해주세요."
        case .photoLibraryPermissionDenied:  return "사진 라이브러리 권한이 필요해요."
        case .cameraUnavailableOnMac:        return "Mac에서는 카메라를 쓸 수 없어요. '+' 버튼으로 갤러리에서 사진을 등록해주세요."
        case .setupFailed(let m):            return "카메라 설정 실패: \(m)"
        case .captureFailed(let m):          return "촬영 실패: \(m)"
        }
    }
}

final class CameraService: NSObject {
    let session = AVCaptureSession()

    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private static let sessionQueue = DispatchQueue(label: "yuna.poby.camera.session")
    private let sessionQueue = CameraService.sessionQueue
    private let videoQueue = DispatchQueue(label: "yuna.poby.camera.video", qos: .userInitiated)
    private var isConfigured = false
    private var pendingCapture: CheckedContinuation<Data, Error>?
    private var currentInput: AVCaptureDeviceInput?
    private var currentPosition: CameraPosition = .back
    private var flashMode: FlashMode = .off
    private var activeBackLens: BackLens = .wide
    private var activeSessionOwners = 0

    var onVideoFrame: (@Sendable (CVPixelBuffer) -> Void)?
    var position: CameraPosition { currentPosition }

    func start() async throws {
        if ProcessInfo.processInfo.isiOSAppOnMac {
            throw CameraServiceError.cameraUnavailableOnMac
        }
        try await ensureCameraPermission()
        try await configureIfNeeded()
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [self] in
                activeSessionOwners += 1
                if !session.isRunning { session.startRunning() }
                cont.resume()
            }
        }
    }

    func stop() {
        sessionQueue.async { [self] in
            activeSessionOwners = max(activeSessionOwners - 1, 0)
            if activeSessionOwners == 0, session.isRunning {
                session.stopRunning()
            }
        }
    }

    func capturePhoto() async throws -> Data {
        let videoOrientation = await Self.currentInterfaceVideoOrientation()
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data, Error>) in
            sessionQueue.async { [self] in
                pendingCapture = cont
                let settings = AVCapturePhotoSettings()
                if let connection = photoOutput.connection(with: .video),
                   connection.isVideoOrientationSupported {
                    connection.videoOrientation = videoOrientation
                }
                if currentInput?.device.hasFlash == true {
                    settings.flashMode = flashMode.avFlashMode
                }
                photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    func setFlashMode(_ mode: FlashMode) {
        sessionQueue.async { [self] in
            flashMode = mode
        }
    }

    func setCameraPosition(_ position: CameraPosition) async throws {
        if ProcessInfo.processInfo.isiOSAppOnMac {
            return
        }
        if position == currentPosition {
            return
        }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [self] in
                do {
                    session.beginConfiguration()
                    try replaceInput(position: position)
                    configureVideoConnections()
                    session.commitConfiguration()
                    cont.resume()
                } catch {
                    session.commitConfiguration()
                    cont.resume(throwing: error)
                }
            }
        }
    }

    func switchCamera() async throws -> CameraPosition {
        if ProcessInfo.processInfo.isiOSAppOnMac {
            return currentPosition
        }
        let next: CameraPosition = currentPosition == .back ? .front : .back
        try await setCameraPosition(next)
        return next
    }

    func setZoomFactor(_ factor: Double) async -> Double {
        await withCheckedContinuation { (cont: CheckedContinuation<Double, Never>) in
            sessionQueue.async { [self] in
                if currentPosition == .back, factor < 1.0 {
                    do {
                        session.beginConfiguration()
                        try replaceInput(position: .back, backLens: .ultraWide)
                        configureVideoConnections()
                        session.commitConfiguration()
                    } catch {
                        session.commitConfiguration()
                    }
                } else if currentPosition == .back, activeBackLens == .ultraWide, factor >= 1.0 {
                    do {
                        session.beginConfiguration()
                        try replaceInput(position: .back, backLens: .wide)
                        configureVideoConnections()
                        session.commitConfiguration()
                    } catch {
                        session.commitConfiguration()
                    }
                }
                guard let device = currentInput?.device else {
                    cont.resume(returning: 1.0)
                    return
                }
                let minZoom = Double(device.minAvailableVideoZoomFactor)
                let maxZoom = min(Double(device.maxAvailableVideoZoomFactor), 3.0)
                let minimumBackZoom = Self.minimumBackZoomFactor() ?? 1.0
                let targetZoom = activeBackLens == .ultraWide ? max(factor / minimumBackZoom, 1.0) : factor
                let clamped = min(max(targetZoom, minZoom), maxZoom)
                do {
                    try device.lockForConfiguration()
                    device.videoZoomFactor = CGFloat(clamped)
                    device.unlockForConfiguration()
                    cont.resume(returning: activeBackLens == .ultraWide ? minimumBackZoom * clamped : clamped)
                } catch {
                    let current = Double(device.videoZoomFactor)
                    cont.resume(returning: activeBackLens == .ultraWide ? minimumBackZoom * current : current)
                }
            }
        }
    }

    func supportedZoomFactors() async -> [Double] {
        await withCheckedContinuation { (cont: CheckedContinuation<[Double], Never>) in
            sessionQueue.async { [self] in
                guard currentPosition == .back else {
                    cont.resume(returning: [1.0])
                    return
                }
                guard let device = currentInput?.device else {
                    cont.resume(returning: [1.0])
                    return
                }
                let minZoom = Double(device.minAvailableVideoZoomFactor)
                let maxZoom = min(Double(device.maxAvailableVideoZoomFactor), 3.0)
                let zoomCandidates = [1.0, 2.0, 3.0].filter { $0 >= minZoom && $0 <= maxZoom }
                let values = if let minimumBackZoom = Self.minimumBackZoomFactor() {
                    [minimumBackZoom] + zoomCandidates
                } else {
                    zoomCandidates
                }
                cont.resume(returning: values.isEmpty ? [1.0] : values)
            }
        }
    }

    func saveToPhotoLibrary(_ imageData: Data) async throws {
        let readWriteStatus = await requestPhotoLibraryAuthorization(for: .readWrite)
        if readWriteStatus == .authorized || readWriteStatus == .limited {
            try await saveToPobyAlbum(imageData)
            return
        }

        let addOnlyStatus = await requestPhotoLibraryAuthorization(for: .addOnly)
        if addOnlyStatus == .authorized || addOnlyStatus == .limited {
            try await saveToLibrary(imageData)
            return
        }

        throw CameraServiceError.photoLibraryPermissionDenied
    }

    private func saveToPobyAlbum(_ imageData: Data) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            let album = Self.albumChangeRequest(named: "poby")
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: imageData, options: nil)
            if let placeholder = request.placeholderForCreatedAsset {
                album?.addAssets([placeholder] as NSArray)
            }
        }
    }

    private func saveToLibrary(_ imageData: Data) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: imageData, options: nil)
        }
    }

    private func requestPhotoLibraryAuthorization(for accessLevel: PHAccessLevel) async -> PHAuthorizationStatus {
        let status = PHPhotoLibrary.authorizationStatus(for: accessLevel)
        guard status == .notDetermined else { return status }
        return await PHPhotoLibrary.requestAuthorization(for: accessLevel)
    }

    private static func albumChangeRequest(named title: String) -> PHAssetCollectionChangeRequest? {
        if let collection = fetchAlbum(named: title) {
            return PHAssetCollectionChangeRequest(for: collection)
        }
        return PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: title)
    }

    static func fetchAlbum(named title: String) -> PHAssetCollection? {
        let fetch = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)
        var result: PHAssetCollection?
        fetch.enumerateObjects { collection, _, stop in
            if collection.localizedTitle == title {
                result = collection
                stop.pointee = true
            }
        }
        return result
    }

    private func ensureCameraPermission() async throws {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted { throw CameraServiceError.cameraPermissionDenied }
        case .denied, .restricted:
            throw CameraServiceError.cameraPermissionDenied
        @unknown default:
            throw CameraServiceError.cameraPermissionDenied
        }
    }

    private func configureIfNeeded() async throws {
        guard !isConfigured else { return }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [self] in
                do {
                    session.beginConfiguration()
                    session.sessionPreset = ProcessInfo.processInfo.isiOSAppOnMac ? .low : .photo

                    try replaceInput(position: currentPosition)
                    configureVideoConnections()

                    guard session.canAddOutput(photoOutput) else {
                        throw CameraServiceError.setupFailed("사진 출력을 추가할 수 없어요.")
                    }
                    session.addOutput(photoOutput)
                    configurePhotoOutputForCurrentPlatform()

                    if !ProcessInfo.processInfo.isiOSAppOnMac {
                        videoOutput.videoSettings = [
                            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                        ]
                        videoOutput.alwaysDiscardsLateVideoFrames = true
                        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
                        if session.canAddOutput(videoOutput) {
                            session.addOutput(videoOutput)
                        }
                    }

                    session.commitConfiguration()
                    isConfigured = true
                    cont.resume()
                } catch {
                    session.commitConfiguration()
                    cont.resume(throwing: error)
                }
            }
        }
    }

    private func replaceInput(position: CameraPosition, backLens: BackLens = .wide) throws {
        let avPosition: AVCaptureDevice.Position = position == .back ? .back : .front
        guard let device = Self.preferredDevice(for: avPosition, backLens: backLens) else {
            let label = position == .back ? "후면" : "전면"
            throw CameraServiceError.setupFailed("\(label) 카메라를 찾을 수 없어요.")
        }
        if currentInput?.device.uniqueID == device.uniqueID {
            currentPosition = position
            activeBackLens = position == .back ? backLens : .wide
            return
        }
        let input = try AVCaptureDeviceInput(device: device)

        let previousInput = currentInput
        if let previousInput {
            session.removeInput(previousInput)
            self.currentInput = nil
        }

        guard session.canAddInput(input) else {
            if let previousInput, session.canAddInput(previousInput) {
                session.addInput(previousInput)
                self.currentInput = previousInput
            }
            throw CameraServiceError.setupFailed("카메라 입력을 추가할 수 없어요.")
        }

        session.addInput(input)
        currentInput = input
        currentPosition = position
        activeBackLens = position == .back ? backLens : .wide
    }

    private func configurePhotoOutputForCurrentPlatform() {
        guard ProcessInfo.processInfo.isiOSAppOnMac else { return }
        photoOutput.maxPhotoQualityPrioritization = .speed
        if photoOutput.isDepthDataDeliverySupported {
            photoOutput.isDepthDataDeliveryEnabled = false
        }
        if photoOutput.isPortraitEffectsMatteDeliverySupported {
            photoOutput.isPortraitEffectsMatteDeliveryEnabled = false
        }
    }

    private func configureVideoConnections() {
        [photoOutput.connection(with: .video), videoOutput.connection(with: .video)].forEach { connection in
            guard let connection else { return }
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = Self.currentVideoOrientation()
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = currentPosition == .front
            }
        }
    }

    private static func preferredDevice(for position: AVCaptureDevice.Position, backLens: BackLens = .wide) -> AVCaptureDevice? {
        if ProcessInfo.processInfo.isiOSAppOnMac {
            return AVCaptureDevice.DiscoverySession(
                    deviceTypes: [.builtInWideAngleCamera, .external],
                    mediaType: .video,
                    position: .unspecified
                ).devices.first
                ?? AVCaptureDevice.default(for: .video)
        }
        if position == .back {
            if backLens == .ultraWide {
                return ultraWideBackDevice()
            }
            return wideBackDevice()
        }
        return AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front)
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
    }

    private static func wideBackDevice() -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back)
    }

    private static func ultraWideBackDevice() -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back)
    }

    private static func minimumBackZoomFactor() -> Double? {
        guard ultraWideBackDevice() != nil else { return nil }
        let virtualDevice = AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back)
        let virtualMinimum = Double(virtualDevice?.minAvailableVideoZoomFactor ?? 1.0)
        return virtualMinimum < 1.0 ? virtualMinimum : 0.5
    }

    private static func currentVideoOrientation() -> AVCaptureVideoOrientation {
        switch UIDevice.current.orientation {
        case .landscapeLeft:
            return .landscapeRight
        case .landscapeRight:
            return .landscapeLeft
        case .portraitUpsideDown:
            return .portraitUpsideDown
        default:
            return .portrait
        }
    }

    @MainActor
    private static func currentInterfaceVideoOrientation() -> AVCaptureVideoOrientation {
        let sceneOrientation = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .interfaceOrientation

        switch sceneOrientation {
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .portrait:
            return .portrait
        default:
            return currentVideoOrientation()
        }
    }
}

private enum BackLens {
    case wide
    case ultraWide
}

private extension FlashMode {
    var avFlashMode: AVCaptureDevice.FlashMode {
        switch self {
        case .off:  return .off
        case .on:   return .on
        case .auto: return .auto
        }
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        onVideoFrame?(pixelBuffer)
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            pendingCapture?.resume(throwing: CameraServiceError.captureFailed(error.localizedDescription))
            pendingCapture = nil
            return
        }
        guard let data = photo.fileDataRepresentation() else {
            pendingCapture?.resume(throwing: CameraServiceError.captureFailed("이미지 데이터 변환 실패"))
            pendingCapture = nil
            return
        }
        pendingCapture?.resume(returning: data)
        pendingCapture = nil
    }
}
