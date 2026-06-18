import CoreGraphics

enum AppMetrics {
    static let iconButton:      CGFloat = 36
    static let iconButtonLarge: CGFloat = 44
    static let iconXS:          CGFloat = 10
    static let iconS:           CGFloat = 14
    static let iconM:           CGFloat = 18
    static let borderHairline: CGFloat = 0.5
    static let borderEmphasis: CGFloat = 2

    enum Camera {
        static let controlsHeight:      CGFloat = 84
        static let shutterSize:         CGFloat = 76
        static let shutterInnerSize:    CGFloat = 60
        static let shutterBorderWidth:  CGFloat = 4
        static let shutterBottomOffset: CGFloat = 14
        static let topChromeHeight:     CGFloat = 44
        static let guideStripHeight:    CGFloat = 78
        static let guideThumbSize:      CGFloat = 56
        static let guideStripWidthFraction: CGFloat = 0.6
        static let guideLineWidth:      CGFloat = 2.5
        static let zoomChipWidth:       CGFloat = 48
        static let zoomChipHeight:      CGFloat = 38
        static let zoomStripHeight:     CGFloat = 42
    }

    enum Gallery {
        static let thumbnailRequestSize = CGSize(width: 360, height: 480)
        static let detailRequestSize = CGSize(width: 1600, height: 2200)
    }

    enum Control {
        static let buttonHeight: CGFloat = 52
    }

    enum GuideExtraction {
        static let loadingBoxSize: CGFloat = 72
        static let spinnerSize: CGFloat = 36
        static let spinnerLineWidth: CGFloat = 3
        static let progressHeight: CGFloat = 4
    }

    enum Onboarding {
        static let landingSpacing: CGFloat = 32
        static let ctaHeight: CGFloat = 64
        static let ctaCornerRadius: CGFloat = 22
        static let topSpacerMin: CGFloat = 56
        static let sectionSpacerMin: CGFloat = 24
        static let bottomSpacerMin: CGFloat = 108
        static let eyebrowBottomPadding: CGFloat = 12
        static let headlineLineSpacing: CGFloat = 6
        static let bodyLineSpacing: CGFloat = 5
        static let highlightHeight: CGFloat = 9
        static let demoCardMaxWidth: CGFloat = 286
        static let demoCardAspectRatio: CGFloat = 0.72
        static let demoCardCornerRadius: CGFloat = 28
        static let demoImageCornerRadius: CGFloat = 24
        static let demoImageInset: CGFloat = 10
        static let matchPillPadding: CGFloat = 14
        static let viewfinderSize: CGFloat = 72
        static let cornerMarkSize: CGFloat = 24
        static let cornerMarkLineWidth: CGFloat = 4
    }
}
