import Foundation

protocol AnalyticsService {
    func log(_ event: String, properties: [String: Any]?)
}

extension AnalyticsService {
    func log(_ event: String) {
        log(event, properties: nil)
    }
}

enum AnalyticsEvent {
    static let tutorialStepViewed = "tutorial_step_viewed"
    static let tutorialCompleted = "tutorial_completed"
    static let cameraPermissionDenied = "camera_permission_denied"
    static let themeSelected = "theme_selected"
    static let aspectRatioChanged = "aspect_ratio_changed"
    static let zoomChanged = "zoom_changed"
    static let flashToggled = "flash_toggled"
    static let cameraFacingToggled = "camera_facing_toggled"
    static let guideApplied = "guide_applied"
    static let photoCaptured = "photo_captured"
    static let capturePreviewViewed = "capture_preview_viewed"
    static let capturePreviewAction = "capture_preview_action"
    static let addGuideOpened = "add_guide_opened"
    static let addGuideMethodSelected = "add_guide_method_selected"
    static let guideCaptureViewed = "guide_capture_viewed"
    static let guideCaptureShutterTapped = "guide_capture_shutter_tapped"
    static let guideCaptureAction = "guide_capture_action"
    static let guideExtractionViewed = "guide_extraction_viewed"
    static let guideSaved = "guide_saved"
    static let guideExtractionCancelled = "guide_extraction_cancelled"
    static let galleryViewed = "gallery_viewed"
    static let galleryPhotoOpened = "gallery_photo_opened"
    static let galleryPhotoDeleteRequested = "gallery_photo_delete_requested"
    static let galleryPhotoDeleted = "gallery_photo_deleted"
}

enum AppAnalyticsConfig {
    static var amplitudeAPIKey: String {
        Bundle.main.object(forInfoDictionaryKey: "AMPLITUDE_API_KEY") as? String ?? ""
    }
}
