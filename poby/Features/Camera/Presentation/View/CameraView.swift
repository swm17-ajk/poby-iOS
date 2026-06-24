import SwiftUI
import PhotosUI

struct CameraView: View {
    @StateObject private var viewModel: CameraViewModel
    @State private var pickedItem: PhotosPickerItem? = nil
    @State private var isRatioPickerVisible = false
    @State private var isThemePickerVisible = false
    @State private var ratioFlash = false
    @State private var shutterFlash = false
    @State private var deviceOrientation = UIDevice.current.orientation
    private let onGuideCaptureRequested: () -> Void
    private let onGuideImagePicked: (Data) -> Void
    private let onGalleryTap: () -> Void

    init(
        viewModel: CameraViewModel? = nil,
        onGuideCaptureRequested: @escaping () -> Void,
        onGuideImagePicked: @escaping (Data) -> Void,
        onGalleryTap: @escaping () -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: viewModel ?? AppDIContainer.shared.makeCameraViewModel()
        )
        self.onGuideCaptureRequested = onGuideCaptureRequested
        self.onGuideImagePicked = onGuideImagePicked
        self.onGalleryTap = onGalleryTap
    }

    var body: some View {
        let palette = viewModel.palette
        if ProcessInfo.processInfo.isiOSAppOnMac {
            MacCameraFallbackView(
                viewModel: viewModel,
                onGuideCaptureRequested: onGuideCaptureRequested,
                onGuideImagePicked: onGuideImagePicked,
                onGalleryTap: onGalleryTap
            )
        } else {
            ZStack {
                palette.surface.ignoresSafeArea()

                VStack(spacing: 0) {
                    TopChromeBar(
                        selectedRatio: viewModel.state.aspectRatio,
                        isFlashOn: viewModel.state.isFlashOn,
                        showFlash: cameraShowsFlash,
                        isMatched: viewModel.isMatched && viewModel.selectedGuide != nil,
                        onRatioTap: {
                            isRatioPickerVisible.toggle()
                            if isRatioPickerVisible { isThemePickerVisible = false }
                        },
                        onThemeTap: {
                            isThemePickerVisible.toggle()
                            if isThemePickerVisible { isRatioPickerVisible = false }
                        },
                        onFlashTap: { viewModel.cycleFlashMode() },
                        palette: palette
                    )
                    .rotationEffect(controlRotation)
                    .padding(.top, AppSpacing.gapS)
                    .background(palette.surface)
                    .animation(.easeInOut(duration: 0.25), value: viewModel.isMatched)

                    cameraBox(palette: palette)

                    palette.surface
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: .infinity)
                }

                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    if shouldShowExternalZoom {
                        zoomControl(palette: palette)
                            .padding(.bottom, AppSpacing.gapM)
                    }

                    GuideListStrip(
                        guides: viewModel.guides,
                        selectedGuideId: viewModel.selectedGuide?.id,
                        thumbnailURL: { viewModel.thumbnailURL(for: $0) },
                        palette: palette,
                        onTapGuide: { viewModel.selectGuide($0) },
                        onLongPressGuide: { viewModel.requestDelete($0) },
                        onTapPlus: { viewModel.presentAddGuideSheet() }
                    )
                    .rotationEffect(controlRotation)

                    ShutterButton(
                        matched: viewModel.isMatched,
                        isCapturing: viewModel.state.status == .capturing,
                        palette: palette,
                        action: { Task { await viewModel.capture() } }
                    )
                    .rotationEffect(controlRotation)
                    .padding(.bottom, AppMetrics.Camera.shutterBottomOffset)
                    .animation(.easeInOut(duration: 0.25), value: viewModel.isMatched)

                    BottomControlsBar(
                        onGalleryTap: onGalleryTap,
                        onFlipTap: { viewModel.switchCamera() },
                        palette: palette
                    )
                    .rotationEffect(controlRotation)
                }
                .ignoresSafeArea(edges: .bottom)

                if isThemePickerVisible {
                    themePicker(palette: palette)
                }

                if isRatioPickerVisible {
                    ratioPicker(palette: palette)
                }

                if viewModel.guides.isEmpty {
                    emptyStateHint
                }

                if case .denied = viewModel.state.status {
                    deniedOverlay
                }
                if case let .failed(message) = viewModel.state.status {
                    errorBanner(message)
                }
                if let savedAt = viewModel.state.lastSavedAt,
                   Date().timeIntervalSince(savedAt) < 1.5 {
                    savedToast.transition(.opacity)
                }

                if let pending = viewModel.state.pendingCapture {
                    CapturedPreviewOverlay(
                        pending: pending,
                        onBack: { viewModel.discardCapture(action: "back") },
                        onRetake: { viewModel.discardCapture(action: "retake") },
                        onSave: { Task { await viewModel.confirmSaveCapture() } },
                        onToggleGuide: { viewModel.togglePendingGuide() },
                        palette: palette
                    )
                }
            }
            .task { await viewModel.onAppear() }
            .onDisappear {
                viewModel.onDisappear()
                UIDevice.current.endGeneratingDeviceOrientationNotifications()
            }
            .onChange(of: viewModel.state.status) { _, status in
                if status == .capturing {
                    withAnimation(.linear(duration: 0.01)) { shutterFlash = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        shutterFlash = false
                    }
                }
            }
            .onChange(of: viewModel.isMatched) { _, matched in
                if matched, viewModel.selectedGuide != nil {
                    isRatioPickerVisible = false
                }
            }
            .onAppear {
                UIDevice.current.beginGeneratingDeviceOrientationNotifications()
                if AppDIContainer.shared.makeSettingsStore().consumePendingOpenAddGuideDialog() {
                    viewModel.presentAddGuideSheet()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                let orientation = UIDevice.current.orientation
                guard orientation.isPortrait || orientation.isLandscape else { return }
                deviceOrientation = orientation
            }
            .confirmationDialog(
                "가이드라인 추가",
                isPresented: $viewModel.state.isAddGuideSheetPresented,
                titleVisibility: .visible
            ) {
                Button("가이드 사진 찍기") {
                    viewModel.logAddGuideMethodSelected(source: "capture")
                    onGuideCaptureRequested()
                }
                Button("갤러리에서 등록") { viewModel.presentPhotoPicker() }
                Button("취소", role: .cancel) {}
            }
            .photosPicker(
                isPresented: $viewModel.state.isPhotoPickerPresented,
                selection: $pickedItem,
                matching: .images
            )
            .onChange(of: pickedItem) { _, newValue in
                guard let newValue else { return }
                Task {
                    if let data = try? await newValue.loadTransferable(type: Data.self) {
                        onGuideImagePicked(data)
                    }
                    pickedItem = nil
                }
            }
            .alert(
                "가이드라인을 삭제할까요?",
                isPresented: Binding(
                    get: { viewModel.guideToDelete != nil },
                    set: { if !$0 { viewModel.cancelDelete() } }
                )
            ) {
                Button("취소", role: .cancel) { viewModel.cancelDelete() }
                Button("삭제", role: .destructive) {
                    if let guide = viewModel.guideToDelete {
                        Task { await viewModel.confirmDelete(guide) }
                    }
                }
            } message: {
                Text("삭제한 가이드라인은 복구할 수 없어요.")
            }
        }
    }

    private var emptyStateHint: some View {
        Text("첫 가이드라인을 추가해보세요")
            .font(AppTypography.body)
            .foregroundStyle(.white.opacity(0.85))
            .multilineTextAlignment(.center)
            .padding(.horizontal, AppSpacing.groupM)
    }

    private var cameraShowsFlash: Bool {
        viewModel.cameraService.position == .back
    }

    private var shouldShowExternalZoom: Bool {
        viewModel.availableZooms.count > 1 && viewModel.state.aspectRatio == .nineSixteen
    }

    private var controlRotation: Angle {
        switch deviceOrientation {
        case .landscapeLeft:
            return .degrees(90)
        case .landscapeRight:
            return .degrees(-90)
        case .portraitUpsideDown:
            return .degrees(180)
        default:
            return .zero
        }
    }

    private func zoomControl(palette: AppPalette) -> some View {
        ZoomControlStrip(
            zooms: viewModel.availableZooms,
            selectedZoom: viewModel.selectedZoom,
            onSelect: { viewModel.selectZoom($0) },
            palette: palette
        )
        .rotationEffect(controlRotation)
    }

    private func cameraBox(palette: AppPalette) -> some View {
        GeometryReader { geo in
            let width = geo.size.width
            let isSquare = viewModel.state.aspectRatio == .oneOne
            let containerRatio = isSquare ? CameraAspectRatio.fourThree.value : viewModel.state.aspectRatio.value
            let containerHeight = width / containerRatio
            let visibleHeight = isSquare ? width : containerHeight
            let maskHeight = max((containerHeight - visibleHeight) / 2, 0)

            ZStack {
                if viewModel.state.status == .ready || viewModel.state.status == .capturing {
                    CameraPreviewView(session: viewModel.session)
                        .frame(width: width, height: isSquare ? width : containerHeight)
                        .position(x: width / 2, y: containerHeight / 2)
                        .clipped()
                }

                if let guide = viewModel.selectedGuide {
                    guideOverlay(guide, visibleSize: CGSize(width: width, height: visibleHeight))
                        .position(x: width / 2, y: containerHeight - maskHeight - visibleHeight / 2)
                        .allowsHitTesting(false)
                        .animation(.easeInOut(duration: 0.25), value: viewModel.isMatched)
                }

                if ratioFlash {
                    Color.black
                }
                if shutterFlash {
                    Color.white
                }

                if isSquare {
                    VStack(spacing: 0) {
                        palette.surface.frame(height: maskHeight)
                        Spacer(minLength: 0)
                        palette.surface.frame(height: maskHeight)
                    }
                }

                if viewModel.availableZooms.count > 1 && viewModel.state.aspectRatio != .nineSixteen {
                    zoomControl(palette: palette)
                    .position(x: width / 2, y: containerHeight - maskHeight - AppSpacing.gapM - 21)
                }
            }
            .background(Color.black)
            .frame(width: width, height: containerHeight)
            .clipped()
        }
        .frame(height: cameraContainerHeight)
    }

    private var cameraContainerHeight: CGFloat {
        let width = UIScreen.main.bounds.width
        let ratio = viewModel.state.aspectRatio == .oneOne ? CameraAspectRatio.fourThree.value : viewModel.state.aspectRatio.value
        return width / ratio
    }

    private func guideOverlay(_ guide: Guide, visibleSize: CGSize) -> some View {
        let aspect = CGFloat(guide.sourceAspectRatio ?? 1.0)
        let fit = bottomAnchoredFit(visibleSize: visibleSize, guideAspect: aspect)
        return SilhouetteOverlay(
            silhouette: guide.silhouette,
            color: viewModel.isMatched ? AppColors.mint : .white,
            lineWidth: AppMetrics.Camera.guideLineWidth,
            glow: true
        )
        .frame(width: fit.width, height: fit.height)
    }

    private func themePicker(palette: AppPalette) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.gapS) {
            ForEach(AppTheme.allCases, id: \.self) { theme in
                optionChip(
                    label: theme.label,
                    selected: theme == viewModel.state.selectedTheme,
                    palette: palette
                ) {
                    viewModel.selectTheme(theme)
                    isThemePickerVisible = false
                }
            }
        }
        .padding(.top, AppMetrics.Camera.topChromeHeight + AppSpacing.groupM)
        .padding(.leading, AppSpacing.edge)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func ratioPicker(palette: AppPalette) -> some View {
        HStack(spacing: AppSpacing.gapS) {
            ForEach(CameraAspectRatio.allCases, id: \.self) { ratio in
                optionChip(
                    label: ratio.rawValue,
                    selected: ratio == viewModel.state.aspectRatio,
                    palette: palette
                ) {
                    if ratio != viewModel.state.aspectRatio {
                        ratioFlash = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                            ratioFlash = false
                        }
                    }
                    viewModel.selectAspectRatio(ratio)
                    isRatioPickerVisible = false
                }
            }
        }
        .padding(.top, AppMetrics.Camera.topChromeHeight + AppSpacing.groupM)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func optionChip(
        label: String,
        selected: Bool,
        palette: AppPalette,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(AppTypography.buttonSecondary)
                .foregroundStyle(selected ? AppColors.mintDeep : palette.onSurface)
                .padding(.horizontal, AppSpacing.gapM)
                .padding(.vertical, AppSpacing.gapS)
                .background(selected ? AppColors.mint : palette.glassFill, in: Capsule())
                .overlay(Capsule().strokeBorder(
                    selected ? AppColors.mint : palette.glassBorder,
                    lineWidth: AppMetrics.borderHairline
                ))
        }
        .buttonStyle(.plain)
    }

    private var deniedOverlay: some View {
        VStack(spacing: AppSpacing.gapM) {
            Text("카메라 권한이 필요해요")
                .font(AppTypography.title)
                .foregroundStyle(.white)
            Text("설정 앱에서 권한을 허용해주세요.")
                .font(AppTypography.body)
                .foregroundStyle(.white.opacity(0.7))
            Button("설정 열기") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(AppTypography.buttonPrimary)
            .foregroundStyle(AppColors.mintDeep)
            .padding(.horizontal, AppSpacing.groupM)
            .padding(.vertical, AppSpacing.gapM)
            .background(AppColors.mint, in: RoundedRectangle(cornerRadius: AppRadius.row))
            .padding(.top, AppSpacing.gapXS)
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

    private var savedToast: some View {
        VStack {
            Spacer()
            Text("저장됨")
                .font(AppTypography.buttonSecondary)
                .foregroundStyle(.white)
                .padding(.horizontal, AppSpacing.groupS)
                .padding(.vertical, AppSpacing.gapS)
                .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: AppRadius.chip))
                .padding(.bottom, AppMetrics.Camera.controlsHeight + AppMetrics.Camera.shutterSize + AppSpacing.groupM)
        }
    }
}

private struct CapturedPreviewOverlay: View {
    let pending: PendingCapture
    let onBack: () -> Void
    let onRetake: () -> Void
    let onSave: () -> Void
    let onToggleGuide: () -> Void
    let palette: AppPalette

    private var image: UIImage? { UIImage(data: pending.imageData) }

    var body: some View {
        GeometryReader { geo in
            let imageFrame = fittedImageFrame(in: geo.size)

            ZStack {
                palette.surface.ignoresSafeArea()

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: imageFrame.width, height: imageFrame.height)
                        .clipped()
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }

                if pending.showGuide, let guide = pending.capturedGuide {
                    let fit = bottomAnchoredFit(
                        visibleSize: CGSize(width: imageFrame.width, height: imageFrame.height),
                        guideAspect: CGFloat(guide.sourceAspectRatio ?? 1.0)
                    )
                    SilhouetteOverlay(
                        silhouette: guide.silhouette,
                        color: .white,
                        lineWidth: AppMetrics.Camera.guideLineWidth,
                        glow: true
                    )
                    .frame(width: fit.width, height: fit.height)
                    .position(
                        x: geo.size.width / 2,
                        y: geo.size.height / 2 + imageFrame.height / 2 - fit.height / 2
                    )
                }

                VStack {
                    HStack {
                        Button(action: onBack) {
                            GlassChip(palette: palette) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: AppMetrics.iconS, weight: .semibold))
                                    .foregroundStyle(palette.onSurface)
                            }
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        if pending.capturedGuide != nil {
                            Button(action: onToggleGuide) {
                                GlassChip(palette: palette) {
                                    Image(systemName: pending.showGuide ? "eye.fill" : "eye.slash.fill")
                                        .font(.system(size: AppMetrics.iconS, weight: .semibold))
                                        .foregroundStyle(palette.onSurface)
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer()
                        Color.clear.frame(width: AppMetrics.iconButton, height: AppMetrics.iconButton)
                    }
                    .padding(.top, AppSpacing.gapS)
                    .padding(.horizontal, AppSpacing.edge)

                    Spacer()

                    HStack(spacing: AppSpacing.gapS) {
                        Button(action: onRetake) {
                            Text("재촬영")
                                .font(AppTypography.bodyEmphasis)
                                .foregroundStyle(palette.onSurface)
                                .frame(maxWidth: .infinity)
                                .frame(height: AppMetrics.Control.buttonHeight)
                                .background(palette.glassFill, in: RoundedRectangle(cornerRadius: AppRadius.thumb))
                        }
                        Button(action: onSave) {
                            Text("저장")
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
    }

    private func fittedImageFrame(in container: CGSize) -> CGSize {
        let imageAspect = pending.aspectRatio.value
        let containerAspect = container.width / container.height
        if imageAspect > containerAspect {
            return CGSize(width: container.width, height: container.width / imageAspect)
        }
        return CGSize(width: container.height * imageAspect, height: container.height)
    }
}

private func bottomAnchoredFit(visibleSize: CGSize, guideAspect: CGFloat) -> CGSize {
    let visibleAspect = visibleSize.width / visibleSize.height
    if guideAspect > visibleAspect {
        return CGSize(width: visibleSize.width, height: visibleSize.width / guideAspect)
    }
    return CGSize(width: visibleSize.height * guideAspect, height: visibleSize.height)
}

private extension View {
    func positionedAboveControls() -> some View {
        let controlsTotal = AppMetrics.Camera.guideStripHeight +
            AppMetrics.Camera.shutterSize +
            AppMetrics.Camera.shutterBottomOffset +
            AppMetrics.Camera.controlsHeight
        return self
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, controlsTotal + AppSpacing.gapM)
    }
}

#if DEBUG

private func cameraPreviewGuide() -> Guide {
    Guide(
        id: UUID(),
        createdAt: Date(),
        silhouette: GuideSilhouette(
            contours: [[
                NormalizedPoint(x: 0.50, y: 0.92),
                NormalizedPoint(x: 0.42, y: 0.88),
                NormalizedPoint(x: 0.40, y: 0.78),
                NormalizedPoint(x: 0.45, y: 0.72),
                NormalizedPoint(x: 0.32, y: 0.68),
                NormalizedPoint(x: 0.26, y: 0.55),
                NormalizedPoint(x: 0.30, y: 0.34),
                NormalizedPoint(x: 0.40, y: 0.46),
                NormalizedPoint(x: 0.40, y: 0.08),
                NormalizedPoint(x: 0.60, y: 0.08),
                NormalizedPoint(x: 0.60, y: 0.46),
                NormalizedPoint(x: 0.70, y: 0.34),
                NormalizedPoint(x: 0.74, y: 0.55),
                NormalizedPoint(x: 0.68, y: 0.68),
                NormalizedPoint(x: 0.55, y: 0.72),
                NormalizedPoint(x: 0.60, y: 0.78),
                NormalizedPoint(x: 0.58, y: 0.88),
            ]],
            faceContour: [
                NormalizedPoint(x: 0.40, y: 0.92),
                NormalizedPoint(x: 0.41, y: 0.86),
                NormalizedPoint(x: 0.43, y: 0.81),
                NormalizedPoint(x: 0.46, y: 0.78),
                NormalizedPoint(x: 0.50, y: 0.77),
                NormalizedPoint(x: 0.54, y: 0.78),
                NormalizedPoint(x: 0.57, y: 0.81),
                NormalizedPoint(x: 0.59, y: 0.86),
                NormalizedPoint(x: 0.60, y: 0.92),
            ]
        ),
        sourceAspectRatio: 0.75
    )
}

#Preview("빈 상태") {
    CameraView(
        viewModel: CameraViewModel(previewState: CameraViewState(status: .ready)),
        onGuideCaptureRequested: {},
        onGuideImagePicked: { _ in },
        onGalleryTap: {}
    )
}

#Preview("가이드 적용") {
    let guide = cameraPreviewGuide()
    return CameraView(
        viewModel: CameraViewModel(
            previewState: CameraViewState(status: .ready),
            previewGuides: [guide, cameraPreviewGuide(), cameraPreviewGuide()],
            previewSelectedGuide: guide
        ),
        onGuideCaptureRequested: {},
        onGuideImagePicked: { _ in },
        onGalleryTap: {}
    )
}

#Preview("매칭 성공") {
    let guide = cameraPreviewGuide()
    return CameraView(
        viewModel: CameraViewModel(
            previewState: CameraViewState(status: .ready),
            previewGuides: [guide, cameraPreviewGuide()],
            previewSelectedGuide: guide,
            previewIsMatched: true
        ),
        onGuideCaptureRequested: {},
        onGuideImagePicked: { _ in },
        onGalleryTap: {}
    )
}

#Preview("권한 거부") {
    CameraView(
        viewModel: CameraViewModel(previewState: CameraViewState(status: .denied)),
        onGuideCaptureRequested: {},
        onGuideImagePicked: { _ in },
        onGalleryTap: {}
    )
}

#endif
