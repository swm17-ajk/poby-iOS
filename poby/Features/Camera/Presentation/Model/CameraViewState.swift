import Foundation

enum CameraAspectRatio: String, CaseIterable, Equatable {
    case fourThree   = "4:3"
    case oneOne      = "1:1"
    case nineSixteen = "9:16"

    func next() -> CameraAspectRatio {
        let all = Self.allCases
        let idx = all.firstIndex(of: self) ?? 0
        return all[(idx + 1) % all.count]
    }
}

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
    var isAddGuideSheetPresented: Bool = false
    var isPhotoPickerPresented: Bool = false
    var aspectRatio: CameraAspectRatio = .nineSixteen
    var isFlashOn: Bool = false

    static let initial = CameraViewState()
}
