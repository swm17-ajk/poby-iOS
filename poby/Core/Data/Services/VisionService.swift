import Foundation
import Vision
import CoreVideo
import UIKit

enum VisionServiceError: LocalizedError {
    case invalidImage
    case noOutlineFound
    case processingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidImage:            return "이미지를 처리할 수 없어요."
        case .noOutlineFound:          return "아웃라인을 찾지 못했어요"
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
            try Self.extractPersonContoursSync(from: cgImage)
        }.value
        async let faceContour = Task.detached(priority: .userInitiated) {
            Self.detectLargestFaceContourSync(in: cgImage)
        }.value

        let personContours = try await contours
        let resolved = if let personContours, personContours.contains(where: { $0.count >= 8 }) {
            personContours
        } else {
            try Self.extractObjectContoursSync(from: cgImage)
        }
        let filtered = resolved.filter { $0.count >= 8 }
        guard !filtered.isEmpty else {
            throw VisionServiceError.noOutlineFound
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

    private static func extractPersonContoursSync(from cgImage: CGImage) throws -> [[NormalizedPoint]]? {
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
            return nil
        }
        do {
            return try extractContours(from: mask)
        } catch VisionServiceError.noOutlineFound {
            return nil
        }
    }

    private static func extractObjectContoursSync(from cgImage: CGImage) throws -> [[NormalizedPoint]] {
        if let foregroundContours = try extractForegroundContoursSync(from: cgImage),
           foregroundContours.contains(where: { $0.count >= 8 }) {
            return foregroundContours
        }

        let darkOnLightContours = try detectObjectContours(from: cgImage, detectsDarkOnLight: true)
        let lightOnDarkContours = try detectObjectContours(from: cgImage, detectsDarkOnLight: false)
        let contours = (darkOnLightContours + lightOnDarkContours)
            .filter { isObjectCandidate($0.normalizedPath.boundingBox) }
            .sorted { contourArea($0.normalizedPath.boundingBox) > contourArea($1.normalizedPath.boundingBox) }
            .prefix(3)
        let resolved = contours.map { contour in
            let points = contour.normalizedPoints.map { NormalizedPoint(x: Double($0.x), y: Double($0.y)) }
            return smoothedContour(points)
        }
        guard !resolved.isEmpty else {
            throw VisionServiceError.noOutlineFound
        }
        return resolved
    }

    private static func extractForegroundContoursSync(from cgImage: CGImage) throws -> [[NormalizedPoint]]? {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            guard let observation = request.results?.first,
                  !observation.allInstances.isEmpty else {
                return nil
            }
            let mask = try observation.generateScaledMaskForImage(
                forInstances: observation.allInstances,
                from: handler
            )
            return try extractContours(from: mask)
        } catch VisionServiceError.noOutlineFound {
            return nil
        } catch {
            throw VisionServiceError.processingFailed(error.localizedDescription)
        }
    }

    private static func detectObjectContours(
        from cgImage: CGImage,
        detectsDarkOnLight: Bool
    ) throws -> [VNContour] {
        let contourRequest = VNDetectContoursRequest()
        contourRequest.contrastAdjustment = 1.0
        contourRequest.detectsDarkOnLight = detectsDarkOnLight
        contourRequest.maximumImageDimension = 512
        let contourHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try contourHandler.perform([contourRequest])
        } catch {
            throw VisionServiceError.processingFailed(error.localizedDescription)
        }
        return contourRequest.results?.first?.topLevelContours ?? []
    }

    private static func extractContours(from mask: CVPixelBuffer) throws -> [[NormalizedPoint]] {
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
            throw VisionServiceError.noOutlineFound
        }
        return observation.topLevelContours.map { contour in
            let points = contour.normalizedPoints.map { NormalizedPoint(x: Double($0.x), y: Double($0.y)) }
            return smoothedContour(points)
        }
    }

    private static func contourArea(_ rect: CGRect) -> CGFloat {
        rect.width * rect.height
    }

    private static func isObjectCandidate(_ rect: CGRect) -> Bool {
        let edgeTolerance = 0.015
        let touchesImageEdge = rect.minX <= edgeTolerance ||
            rect.minY <= edgeTolerance ||
            rect.maxX >= 1 - edgeTolerance ||
            rect.maxY >= 1 - edgeTolerance
        let coversAlmostWholeImage = rect.width >= 0.92 || rect.height >= 0.92
        let tooSmall = rect.width < 0.03 || rect.height < 0.03
        return !touchesImageEdge && !coversAlmostWholeImage && !tooSmall
    }

    private static func smoothedContour(_ points: [NormalizedPoint]) -> [NormalizedPoint] {
        guard points.count > 12 else { return points }
        let step = max(1, Int(ceil(Double(points.count) / 96.0)))
        let sampled = points.enumerated().compactMap { index, point in
            index % step == 0 ? point : nil
        }
        guard sampled.count > 4 else { return sampled }
        return sampled.indices.map { index in
            let previous = sampled[(index - 1 + sampled.count) % sampled.count]
            let current = sampled[index]
            let next = sampled[(index + 1) % sampled.count]
            return NormalizedPoint(
                x: (previous.x + current.x * 2 + next.x) / 4,
                y: (previous.y + current.y * 2 + next.y) / 4
            )
        }
    }
}
