import Foundation

struct GuideExtractionViewState: Equatable {
    let sourceImage: Data

    static func initial(image: Data) -> GuideExtractionViewState {
        GuideExtractionViewState(sourceImage: image)
    }
}
