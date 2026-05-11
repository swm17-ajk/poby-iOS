import Foundation
import UIKit
import Combine

enum FileGuideRepositoryError: LocalizedError {
    case thumbnailGenerationFailed
    case directoryUnavailable

    var errorDescription: String? {
        switch self {
        case .thumbnailGenerationFailed: return "썸네일 생성 실패"
        case .directoryUnavailable:      return "Documents 디렉터리 접근 실패"
        }
    }
}

final class FileGuideRepository: GuideRepositoryProtocol {
    private let fileManager = FileManager.default
    private let metadataURL: URL
    private let imagesDir: URL
    private let thumbsDir: URL

    private let queue = DispatchQueue(label: "yuna.poby.guide-repo", attributes: .concurrent)
    private var cache: [Guide] = []
    private let subject = CurrentValueSubject<[Guide], Never>([])

    var guidesPublisher: AnyPublisher<[Guide], Never> {
        subject.eraseToAnyPublisher()
    }

    init() throws {
        guard let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw FileGuideRepositoryError.directoryUnavailable
        }
        self.metadataURL = docs.appendingPathComponent("guides.json")
        self.imagesDir   = docs.appendingPathComponent("guide-images")
        self.thumbsDir   = docs.appendingPathComponent("guide-thumbs")
        try fileManager.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: thumbsDir, withIntermediateDirectories: true)
        loadFromDisk()
    }

    @discardableResult
    func add(silhouette: GuideSilhouette, sourceImage: Data) async throws -> Guide {
        let id = UUID()
        let guide = Guide(id: id, createdAt: Date(), silhouette: silhouette)

        let srcURL = imagesDir.appendingPathComponent("\(id.uuidString).jpg")
        try sourceImage.write(to: srcURL, options: .atomic)

        let thumbData = try Self.makeThumbnail(from: sourceImage)
        let thumbURL = thumbsDir.appendingPathComponent("\(id.uuidString).jpg")
        try thumbData.write(to: thumbURL, options: .atomic)

        cache.append(guide)
        try saveToDisk()
        subject.send(cache)
        return guide
    }

    func sourceImageURL(for id: UUID) -> URL {
        imagesDir.appendingPathComponent("\(id.uuidString).jpg")
    }

    func thumbnailURL(for id: UUID) -> URL {
        thumbsDir.appendingPathComponent("\(id.uuidString).jpg")
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: metadataURL),
              let guides = try? JSONDecoder().decode([Guide].self, from: data) else { return }
        cache = guides
        subject.send(cache)
    }

    private func saveToDisk() throws {
        let data = try JSONEncoder().encode(cache)
        try data.write(to: metadataURL, options: .atomic)
    }

    private static func makeThumbnail(from data: Data, size: CGSize = CGSize(width: 200, height: 200)) throws -> Data {
        guard let image = UIImage(data: data) else {
            throw FileGuideRepositoryError.thumbnailGenerationFailed
        }
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { _ in
            let aspect = image.size.width / image.size.height
            let drawRect: CGRect
            if aspect > 1 {
                let w = size.height * aspect
                drawRect = CGRect(x: (size.width - w) / 2, y: 0, width: w, height: size.height)
            } else {
                let h = size.width / aspect
                drawRect = CGRect(x: 0, y: (size.height - h) / 2, width: size.width, height: h)
            }
            image.draw(in: drawRect)
        }
        guard let jpeg = img.jpegData(compressionQuality: 0.75) else {
            throw FileGuideRepositoryError.thumbnailGenerationFailed
        }
        return jpeg
    }
}
