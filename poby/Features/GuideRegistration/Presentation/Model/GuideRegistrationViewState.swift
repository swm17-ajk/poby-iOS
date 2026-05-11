import Foundation

enum GuideRegistrationViewState: Equatable {
    case idle
    case detecting
    case success
    case failed(message: String)
}
