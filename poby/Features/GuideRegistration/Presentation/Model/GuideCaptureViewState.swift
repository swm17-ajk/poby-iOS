import Foundation

struct GuideCaptureViewState: Equatable {
    enum Status: Equatable {
        case idle
        case preparing
        case ready
        case capturing
        case denied
        case failed(message: String)
    }

    var status: Status = .idle
    var capturedImage: Data? = nil

    static let initial = GuideCaptureViewState()
}
