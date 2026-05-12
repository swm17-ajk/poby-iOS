import Foundation
import Vision
import CoreVideo
import UIKit

enum VisionServiceError: LocalizedError {
    case invalidImage
    case noPersonFound
    case processingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidImage:            return "이미지를 처리할 수 없어요."
        case .noPersonFound:           return "인물을 찾지 못했어요"
        case .processingFailed(let m): return "분석 실패: \(m)"
        }
    }
}

final class VisionService {
    /// 라이브 프레임에서 사람의 정규화된 bounding box (lower-left 좌표계).
    /// 동기 호출 — 호출자가 백그라운드 큐에서 부르는 책임.
    func personBoundingRect(in pixelBuffer: CVPixelBuffer) -> CGRect? {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .balanced
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do { try handler.perform([request]) } catch { return nil }
        guard let mask = request.results?.first?.pixelBuffer else { return nil }
        return Self.normalizedBoundingBox(of: mask)
    }

    private static func normalizedBoundingBox(of mask: CVPixelBuffer) -> CGRect? {
        let width = CVPixelBufferGetWidth(mask)
        let height = CVPixelBufferGetHeight(mask)
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(mask)?.assumingMemoryBound(to: UInt8.self) else {
            return nil
        }
        let stride = CVPixelBufferGetBytesPerRow(mask)
        var minX = width, maxX = 0, minY = height, maxY = 0
        var anyHit = false
        let step = max(1, min(width, height) / 64)
        for y in Swift.stride(from: 0, to: height, by: step) {
            let row = base.advanced(by: y * stride)
            for x in Swift.stride(from: 0, to: width, by: step) where row[x] > 127 {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
                anyHit = true
            }
        }
        guard anyHit else { return nil }
        return CGRect(
            x: Double(minX) / Double(width),
            y: Double(height - maxY) / Double(height),
            width: Double(maxX - minX) / Double(width),
            height: Double(maxY - minY) / Double(height)
        )
    }

    func extractSilhouette(from imageData: Data) async throws -> GuideSilhouette {
        guard let cgImage = UIImage(data: imageData)?.cgImage else {
            throw VisionServiceError.invalidImage
        }

        async let contours = Task.detached(priority: .userInitiated) {
            try Self.extractContoursSync(from: cgImage)
        }.value
        async let faceContour = Task.detached(priority: .userInitiated) {
            Self.detectLargestFaceContourSync(in: cgImage)
        }.value

        let resolved = try await contours
        let filtered = resolved.filter { $0.count >= 8 }
        guard !filtered.isEmpty else {
            throw VisionServiceError.noPersonFound
        }
        return GuideSilhouette(contours: filtered, faceContour: await faceContour)
    }

    private static func detectLargestFaceContourSync(in cgImage: CGImage) -> [NormalizedPoint]? {
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do { try handler.perform([request]) } catch { return nil }
        guard let faces = request.results, !faces.isEmpty else { return nil }
        let face = faces.max(by: { lhs, rhs in
            (lhs.boundingBox.width * lhs.boundingBox.height) <
                (rhs.boundingBox.width * rhs.boundingBox.height)
        })!
        guard let contour = face.landmarks?.faceContour else { return nil }
        let box = face.boundingBox  // 정규화된 이미지 좌표 (lower-left)
        // faceContour 포인트는 face bbox 내부 정규화 → 이미지 정규화로 변환
        return contour.normalizedPoints.map { p in
            NormalizedPoint(
                x: box.origin.x + Double(p.x) * box.width,
                y: box.origin.y + Double(p.y) * box.height
            )
        }
    }

    private static func extractContoursSync(from cgImage: CGImage) throws -> [[NormalizedPoint]] {
        let segRequest = VNGeneratePersonSegmentationRequest()
        segRequest.qualityLevel = .accurate
        segRequest.outputPixelFormat = kCVPixelFormatType_OneComponent8
        let segHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try segHandler.perform([segRequest])
        } catch {
            throw VisionServiceError.processingFailed(error.localizedDescription)
        }
        guard let mask = segRequest.results?.first?.pixelBuffer else {
            throw VisionServiceError.noPersonFound
        }

        let contourRequest = VNDetectContoursRequest()
        contourRequest.contrastAdjustment = 1.0
        contourRequest.detectsDarkOnLight = false
        contourRequest.maximumImageDimension = 512
        let contourHandler = VNImageRequestHandler(cvPixelBuffer: mask, options: [:])
        do {
            try contourHandler.perform([contourRequest])
        } catch {
            throw VisionServiceError.processingFailed(error.localizedDescription)
        }
        guard let observation = contourRequest.results?.first else {
            throw VisionServiceError.noPersonFound
        }
        return observation.topLevelContours.map { contour in
            contour.normalizedPoints.map { NormalizedPoint(x: Double($0.x), y: Double($0.y)) }
        }
    }
}
