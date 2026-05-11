import Foundation

@MainActor
final class GuideRegistrationViewModel: ObservableObject {
    @Published private(set) var state: GuideRegistrationViewState = .idle

    init() {}
}
