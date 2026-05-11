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
    func extractSilhouette(from imageData: Data) async throws -> GuideSilhouette {
        guard let cgImage = UIImage(data: imageData)?.cgImage else {
            throw VisionServiceError.invalidImage
        }

        let contours = try await Task.detached(priority: .userInitiated) {
            try Self.extractContoursSync(from: cgImage)
        }.value

        let filtered = contours.filter { $0.count >= 8 }
        guard !filtered.isEmpty else {
            throw VisionServiceError.noPersonFound
        }
        return GuideSilhouette(contours: filtered)
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
