import CoreGraphics
import Foundation

enum CameraAspectRatio: String, CaseIterable, Codable, Equatable {
    case nineSixteen = "9:16"
    case fourThree   = "3:4"
    case oneOne      = "1:1"

    var value: CGFloat {
        switch self {
        case .nineSixteen: return 9.0 / 16.0
        case .fourThree:   return 3.0 / 4.0
        case .oneOne:      return 1.0
        }
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "9:16": self = .nineSixteen
        case "1:1": self = .oneOne
        case "3:4", "4:3": self = .fourThree
        default: self = .fourThree
        }
    }
}

struct PendingCapture: Equatable {
    let imageData: Data
    let aspectRatio: CameraAspectRatio
    let capturedGuide: Guide?
    var showGuide: Bool
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
    var selectedTheme: AppTheme = .warm
    var pendingCapture: PendingCapture?

    static let initial = CameraViewState()
}
