import Foundation

@MainActor
final class GuideExtractionViewModel: ObservableObject {
    @Published private(set) var state: GuideExtractionViewState

    init(imageData: Data) {
        self.state = .initial(image: imageData)
    }
}
