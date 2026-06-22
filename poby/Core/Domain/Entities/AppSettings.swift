import Foundation

enum CameraPosition: String, Codable, Equatable {
    case back
    case front
}

enum FlashMode: String, Codable, Equatable {
    case off
    case on
    case auto

    func next() -> FlashMode {
        switch self {
        case .off:  return .on
        case .on:   return .auto
        case .auto: return .off
        }
    }
}

enum GuideColorPreference: String, Codable, Equatable {
    case white
    case mint

    func toggled() -> GuideColorPreference {
        self == .white ? .mint : .white
    }
}

struct AppSettings: Codable, Equatable {
    var hasCompletedOnboarding: Bool
    var hasSeenTutorialDetail: Bool
    var pendingOpenAddGuideDialog: Bool
    var selectedGuideId: UUID?
    var selectedZoom: Double
    var selectedAspectRatio: CameraAspectRatio
    var guideColor: GuideColorPreference
    var flashMode: FlashMode
    var cameraPosition: CameraPosition
    var selectedTheme: AppTheme

    enum CodingKeys: String, CodingKey {
        case hasCompletedOnboarding
        case hasSeenTutorialDetail
        case pendingOpenAddGuideDialog
        case selectedGuideId
        case selectedZoom
        case selectedAspectRatio
        case guideColor
        case flashMode
        case cameraPosition
        case selectedTheme
    }

    init(
        hasCompletedOnboarding: Bool,
        hasSeenTutorialDetail: Bool,
        pendingOpenAddGuideDialog: Bool,
        selectedGuideId: UUID?,
        selectedZoom: Double,
        selectedAspectRatio: CameraAspectRatio,
        guideColor: GuideColorPreference,
        flashMode: FlashMode,
        cameraPosition: CameraPosition,
        selectedTheme: AppTheme
    ) {
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.hasSeenTutorialDetail = hasSeenTutorialDetail
        self.pendingOpenAddGuideDialog = pendingOpenAddGuideDialog
        self.selectedGuideId = selectedGuideId
        self.selectedZoom = selectedZoom
        self.selectedAspectRatio = selectedAspectRatio
        self.guideColor = guideColor
        self.flashMode = flashMode
        self.cameraPosition = cameraPosition
        self.selectedTheme = selectedTheme
    }

    init(from decoder: Decoder) throws {
        let defaults = Self.defaults
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? defaults.hasCompletedOnboarding
        self.hasSeenTutorialDetail = try container.decodeIfPresent(Bool.self, forKey: .hasSeenTutorialDetail) ?? defaults.hasSeenTutorialDetail
        self.pendingOpenAddGuideDialog = try container.decodeIfPresent(Bool.self, forKey: .pendingOpenAddGuideDialog) ?? defaults.pendingOpenAddGuideDialog
        self.selectedGuideId = try container.decodeIfPresent(UUID.self, forKey: .selectedGuideId) ?? defaults.selectedGuideId
        self.selectedZoom = try container.decodeIfPresent(Double.self, forKey: .selectedZoom) ?? defaults.selectedZoom
        self.selectedAspectRatio = try container.decodeIfPresent(CameraAspectRatio.self, forKey: .selectedAspectRatio) ?? defaults.selectedAspectRatio
        self.guideColor = try container.decodeIfPresent(GuideColorPreference.self, forKey: .guideColor) ?? defaults.guideColor
        self.flashMode = try container.decodeIfPresent(FlashMode.self, forKey: .flashMode) ?? defaults.flashMode
        self.cameraPosition = try container.decodeIfPresent(CameraPosition.self, forKey: .cameraPosition) ?? defaults.cameraPosition
        self.selectedTheme = try container.decodeIfPresent(AppTheme.self, forKey: .selectedTheme) ?? defaults.selectedTheme
    }

    static let defaults = AppSettings(
        hasCompletedOnboarding: false,
        hasSeenTutorialDetail: false,
        pendingOpenAddGuideDialog: false,
        selectedGuideId: nil,
        selectedZoom: 1.0,
        selectedAspectRatio: .fourThree,
        guideColor: .white,
        flashMode: .off,
        cameraPosition: .back,
        selectedTheme: .warm
    )
}
