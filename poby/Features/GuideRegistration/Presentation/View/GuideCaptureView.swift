import SwiftUI

struct GuideCaptureView: View {
    @StateObject private var viewModel: GuideCaptureViewModel
    @State private var settings = UserDefaultsAppSettingsStore().load()
    @State private var shutterFlash = false
    @State private var pinchStartZoom: Double?
    private let onCancel: () -> Void
    private let onConfirmed: (Data) -> Void

    init(
        viewModel: GuideCaptureViewModel? = nil,
        onCancel: @escaping () -> Void,
        onConfirmed: @escaping (Data) -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: viewModel ?? AppDIContainer.shared.makeGuideCaptureViewModel()
        )
        self.onCancel = onCancel
        self.onConfirmed = onConfirmed
    }

    var body: some View {
        let palette = settings.selectedTheme.palette
        ZStack {
            palette.surface.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.top, AppSpacing.gapS)
                    .background(palette.surface)

                guideCameraBox(palette: palette)

                Spacer(minLength: 0)
            }

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                ShutterButton(
                    isCapturing: viewModel.state.status == .capturing,
                    palette: palette,
                    action: { Task { await viewModel.capture() } }
                )
                .padding(.bottom, AppMetrics.Camera.shutterBottomOffset)

                palette.surface
                    .frame(height: AppMetrics.Camera.controlsHeight)
            }
            .ignoresSafeArea(edges: .bottom)

            if case .denied = viewModel.state.status {
                deniedOverlay
            }
            if case let .failed(message) = viewModel.state.status {
                errorBanner(message)
            }

            if let data = viewModel.state.capturedImage {
                recaptureView(imageData: data, palette: palette)
            }
        }
        .navigationBarBackButtonHidden(true)
        .task { await viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        .onAppear { settings = AppDIContainer.shared.makeSettingsStore().load() }
        .onChange(of: viewModel.state.status) { _, status in
            if status == .capturing, viewModel.isFlashOn {
                shutterFlash = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    shutterFlash = false
                }
            }
        }
    }

    @ViewBuilder
    private var topBar: some View {
        let palette = settings.selectedTheme.palette
        HStack {
            Button(action: onCancel) {
                GlassChip(palette: palette) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: AppMetrics.iconS, weight: .semibold))
                        .foregroundStyle(palette.onSurface)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Text("guide_capture_title")
                .font(AppTypography.hintSmall)
                .foregroundStyle(palette.onSurface)
                .padding(.horizontal, AppSpacing.gapM)
                .padding(.vertical, 8)
                .background(Capsule().fill(.black.opacity(0.4)))

            Spacer()

            Button(action: { viewModel.toggleFlash() }) {
                GlassChip(palette: palette) {
                    Image(systemName: viewModel.isFlashOn ? "bolt.fill" : "bolt.slash")
                        .font(.system(size: AppMetrics.iconS, weight: .semibold))
                        .foregroundStyle(palette.onSurface)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.edge)
    }

    private func guideCameraBox(palette: AppPalette) -> some View {
        GeometryReader { geo in
            let width = geo.size.width
            let ratio = settings.selectedAspectRatio.value
            let topOffset = settings.selectedAspectRatio == .oneOne ? width / 6 : 0
            let height = width / ratio

            ZStack {
                if viewModel.state.status == .ready || viewModel.state.status == .capturing {
                    CameraPreviewView(session: viewModel.session)
                        .frame(width: width, height: height)
                        .clipped()
                }
                if shutterFlash {
                    Color.white
                }
            }
            .frame(width: width, height: height)
            .padding(.top, topOffset)
        }
        .frame(height: guideCameraContainerHeight)
        .simultaneousGesture(pinchZoomGesture)
    }

    private var pinchZoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                let baseZoom = pinchStartZoom ?? viewModel.selectedZoom
                if pinchStartZoom == nil {
                    pinchStartZoom = baseZoom
                }
                viewModel.pinchZoom(to: baseZoom * Double(scale), isFinal: false)
            }
            .onEnded { scale in
                let baseZoom = pinchStartZoom ?? viewModel.selectedZoom
                viewModel.pinchZoom(to: baseZoom * Double(scale), isFinal: true)
                pinchStartZoom = nil
            }
    }

    private var guideCameraContainerHeight: CGFloat {
        let width = UIScreen.main.bounds.width
        let topOffset = settings.selectedAspectRatio == .oneOne ? width / 6 : 0
        return topOffset + width / settings.selectedAspectRatio.value
    }

    private func recaptureView(imageData: Data, palette: AppPalette) -> some View {
        ZStack {
            palette.surface.ignoresSafeArea()

            if let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            VStack {
                HStack {
                    Button(action: onCancel) {
                        GlassChip(palette: palette) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: AppMetrics.iconS, weight: .semibold))
                                .foregroundStyle(palette.onSurface)
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.top, AppSpacing.gapS)
                .padding(.horizontal, AppSpacing.edge)

                Spacer()

                HStack(spacing: AppSpacing.gapS) {
                    Button(action: { viewModel.discardCaptured() }) {
                        Text("common_retake")
                            .font(AppTypography.bodyEmphasis)
                            .foregroundStyle(palette.onSurface)
                            .frame(maxWidth: .infinity)
                            .frame(height: AppMetrics.Control.buttonHeight)
                            .background(palette.glassFill, in: RoundedRectangle(cornerRadius: AppRadius.thumb))
                    }
                    Button(action: {
                        viewModel.confirmCaptured()
                        onConfirmed(imageData)
                    }) {
                        Text("common_done")
                            .font(AppTypography.buttonPrimary)
                            .foregroundStyle(AppColors.mintDeep)
                            .frame(maxWidth: .infinity)
                            .frame(height: AppMetrics.Control.buttonHeight)
                            .background(AppColors.mint, in: RoundedRectangle(cornerRadius: AppRadius.thumb))
                    }
                }
                .padding(.horizontal, AppSpacing.edge)
                .frame(height: AppMetrics.Camera.controlsHeight)
                .background(palette.surface)
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private var deniedOverlay: some View {
        VStack(spacing: AppSpacing.gapM) {
            Text("camera_permission_title")
                .font(AppTypography.title)
                .foregroundStyle(.white)
            Text("camera_permission_message")
                .font(AppTypography.body)
                .foregroundStyle(.white.opacity(0.7))
            Button("camera_permission_open_settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(AppTypography.buttonPrimary)
            .foregroundStyle(AppColors.mintDeep)
            .padding(.horizontal, AppSpacing.groupM)
            .padding(.vertical, AppSpacing.gapM)
            .background(AppColors.mint, in: RoundedRectangle(cornerRadius: AppRadius.row))
        }
        .padding(AppSpacing.groupM)
    }

    private func errorBanner(_ message: String) -> some View {
        VStack {
            Text(message)
                .font(AppTypography.body)
                .foregroundStyle(.white)
                .padding(.horizontal, AppSpacing.gapM)
                .padding(.vertical, AppSpacing.gapS)
                .background(AppColors.danger.opacity(0.9), in: RoundedRectangle(cornerRadius: AppRadius.row))
                .padding(.top, AppSpacing.groupM)
                .padding(.horizontal, AppSpacing.edge)
            Spacer()
        }
    }
}

#if DEBUG

private func capturePreviewSamplePhoto() -> Data {
    let size = CGSize(width: 400, height: 600)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.jpegData(withCompressionQuality: 0.8) { ctx in
        let cg = ctx.cgContext
        let cs = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(
            colorsSpace: cs,
            colors: [UIColor(white: 0.3, alpha: 1).cgColor, UIColor.black.cgColor] as CFArray,
            locations: [0, 1]
        )!
        cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
    }
}

#Preview("촬영 대기") {
    GuideCaptureView(
        viewModel: GuideCaptureViewModel(previewState: GuideCaptureViewState(status: .ready)),
        onCancel: {},
        onConfirmed: { _ in }
    )
}

#Preview("재촬영 카드") {
    GuideCaptureView(
        viewModel: GuideCaptureViewModel(
            previewState: GuideCaptureViewState(
                status: .ready,
                capturedImage: capturePreviewSamplePhoto()
            )
        ),
        onCancel: {},
        onConfirmed: { _ in }
    )
}

#Preview("권한 거부") {
    GuideCaptureView(
        viewModel: GuideCaptureViewModel(previewState: GuideCaptureViewState(status: .denied)),
        onCancel: {},
        onConfirmed: { _ in }
    )
}

#endif
