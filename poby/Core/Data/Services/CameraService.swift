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
    private let sessionQueue = DispatchQueue(label: "yuna.poby.camera.session")
    private let videoQueue = DispatchQueue(label: "yuna.poby.camera.video", qos: .userInitiated)
    private var isConfigured = false
    private var pendingCapture: CheckedContinuation<Data, Error>?
    private var currentInput: AVCaptureDeviceInput?
    private var currentPosition: CameraPosition = .back
    private var flashMode: FlashMode = .off

    var onVideoFrame: (@Sendable (CVPixelBuffer) -> Void)?
    var position: CameraPosition { currentPosition }

    func start() async throws {
        if ProcessInfo.processInfo.isiOSAppOnMac {
            throw CameraServiceError.cameraUnavailableOnMac
        }
        try await ensureCameraPermission()
        try await configureIfNeeded()
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [session] in
                if !session.isRunning { session.startRunning() }
                cont.resume()
            }
        }
    }

    func stop() {
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    func capturePhoto() async throws -> Data {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data, Error>) in
            sessionQueue.async { [self] in
                pendingCapture = cont
                let settings = AVCapturePhotoSettings()
                if let connection = photoOutput.connection(with: .video),
                   connection.isVideoOrientationSupported {
                    connection.videoOrientation = Self.currentVideoOrientation()
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
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [self] in
                do {
                    session.beginConfiguration()
                    try replaceInput(position: position)
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
                guard let device = currentInput?.device else {
                    cont.resume(returning: 1.0)
                    return
                }
                let minZoom = Double(device.minAvailableVideoZoomFactor)
                let maxZoom = min(Double(device.maxAvailableVideoZoomFactor), 3.0)
                let clamped = min(max(factor, minZoom), maxZoom)
                do {
                    try device.lockForConfiguration()
                    device.videoZoomFactor = CGFloat(clamped)
                    device.unlockForConfiguration()
                    cont.resume(returning: clamped)
                } catch {
                    cont.resume(returning: Double(device.videoZoomFactor))
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
                let values = [0.6, 1.0, 2.0, 3.0].filter { $0 >= minZoom && $0 <= maxZoom }
                cont.resume(returning: values.isEmpty ? [1.0] : values)
            }
        }
    }

    func saveToPhotoLibrary(_ imageData: Data) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw CameraServiceError.photoLibraryPermissionDenied
        }
        try await PHPhotoLibrary.shared().performChanges {
            let album = Self.albumChangeRequest(named: "poby")
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: imageData, options: nil)
            if let placeholder = request.placeholderForCreatedAsset {
                album?.addAssets([placeholder] as NSArray)
            }
        }
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

    private func replaceInput(position: CameraPosition) throws {
        if let currentInput {
            session.removeInput(currentInput)
            self.currentInput = nil
        }

        let avPosition: AVCaptureDevice.Position = position == .back ? .back : .front
        guard let device = Self.preferredDevice(for: avPosition) else {
            let label = position == .back ? "후면" : "전면"
            throw CameraServiceError.setupFailed("\(label) 카메라를 찾을 수 없어요.")
        }
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            throw CameraServiceError.setupFailed("카메라 입력을 추가할 수 없어요.")
        }
        session.addInput(input)
        currentInput = input
        currentPosition = position
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

    private static func preferredDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        if ProcessInfo.processInfo.isiOSAppOnMac {
            return AVCaptureDevice.DiscoverySession(
                    deviceTypes: [.builtInWideAngleCamera, .external],
                    mediaType: .video,
                    position: .unspecified
                ).devices.first
                ?? AVCaptureDevice.default(for: .video)
        }
        if position == .back {
            return AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        }
        return AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front)
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
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
