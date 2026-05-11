import AVFoundation
import Photos
import UIKit

enum CameraServiceError: LocalizedError {
    case cameraPermissionDenied
    case photoLibraryPermissionDenied
    case setupFailed(String)
    case captureFailed(String)

    var errorDescription: String? {
        switch self {
        case .cameraPermissionDenied:        return "카메라 권한이 필요해요. 설정에서 허용해주세요."
        case .photoLibraryPermissionDenied:  return "사진 라이브러리 권한이 필요해요."
        case .setupFailed(let m):            return "카메라 설정 실패: \(m)"
        case .captureFailed(let m):          return "촬영 실패: \(m)"
        }
    }
}

final class CameraService: NSObject {
    let session = AVCaptureSession()

    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "yuna.poby.camera.session")
    private var isConfigured = false
    private var pendingCapture: CheckedContinuation<Data, Error>?

    func start() async throws {
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
                photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    func saveToPhotoLibrary(_ imageData: Data) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw CameraServiceError.photoLibraryPermissionDenied
        }
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: imageData, options: nil)
        }
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
                    session.sessionPreset = .photo

                    guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                        throw CameraServiceError.setupFailed("후면 카메라를 찾을 수 없어요.")
                    }
                    let input = try AVCaptureDeviceInput(device: device)
                    guard session.canAddInput(input) else {
                        throw CameraServiceError.setupFailed("카메라 입력을 추가할 수 없어요.")
                    }
                    session.addInput(input)

                    guard session.canAddOutput(photoOutput) else {
                        throw CameraServiceError.setupFailed("사진 출력을 추가할 수 없어요.")
                    }
                    session.addOutput(photoOutput)

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
