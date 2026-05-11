import Foundation

struct CameraViewState: Equatable {
    enum Status: Equatable {
        case idle
        case preparing
        case ready
        case capturing
        case denied
        case failed(message: String)
    }

    var status: Status = .idle
    var lastSavedAt: Date? = nil

    static let initial = CameraViewState()
}
