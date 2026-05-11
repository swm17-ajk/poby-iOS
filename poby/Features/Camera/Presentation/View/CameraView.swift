import SwiftUI
import PhotosUI

struct CameraView: View {
    @StateObject private var viewModel: CameraViewModel
    @State private var pickedItem: PhotosPickerItem? = nil
    private let onGuideCaptureRequested: () -> Void
    private let onGuideImagePicked: (Data) -> Void

    init(
        viewModel: CameraViewModel? = nil,
        onGuideCaptureRequested: @escaping () -> Void,
        onGuideImagePicked: @escaping (Data) -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: viewModel ?? AppDIContainer.shared.makeCameraViewModel()
        )
        self.onGuideCaptureRequested = onGuideCaptureRequested
        self.onGuideImagePicked = onGuideImagePicked
    }

    var body: some View {
        ZStack {
            AppColors.cameraBlack.ignoresSafeArea()

            if viewModel.state.status == .ready || viewModel.state.status == .capturing {
                CameraPreviewView(session: viewModel.session)
                    .ignoresSafeArea()
            }

            if let guide = viewModel.selectedGuide {
                SilhouetteOverlay(
                    silhouette: guide.silhouette,
                    color: viewModel.isMatched ? AppColors.mint : .white,
                    lineWidth: 2.5,
                    glow: true
                )
                .aspectRatio(CGFloat(guide.sourceAspectRatio ?? 1.0), contentMode: .fit)
                .allowsHitTesting(false)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.25), value: viewModel.isMatched)
            }

            VStack(spacing: 0) {
                TopChromeBar(
                    ratioLabel: viewModel.state.aspectRatio.rawValue,
                    isFlashOn: viewModel.state.isFlashOn,
                    isMatched: viewModel.isMatched,
                    onRatioTap: { viewModel.cycleAspectRatio() },
                    onFlashTap: { viewModel.toggleFlash() }
                )
                .padding(.top, AppSpacing.gapS)
                .animation(.easeInOut(duration: 0.25), value: viewModel.isMatched)

                Spacer(minLength: 0)

                if viewModel.guides.isEmpty {
                    emptyStateHint
                        .padding(.bottom, AppSpacing.gapM)
                }

                GuideListStrip(
                    guides: viewModel.guides,
                    selectedGuideId: viewModel.selectedGuide?.id,
                    thumbnailURL: { viewModel.thumbnailURL(for: $0) },
                    onTapGuide: { viewModel.selectGuide($0) },
                    onLongPressGuide: { viewModel.requestDelete($0) },
                    onTapPlus: { viewModel.presentAddGuideSheet() }
                )

                ShutterButton(
                    matched: viewModel.isMatched,
                    isCapturing: viewModel.state.status == .capturing,
                    action: { Task { await viewModel.capture() } }
                )
                .padding(.bottom, AppMetrics.Camera.shutterBottomOffset)
                .animation(.easeInOut(duration: 0.25), value: viewModel.isMatched)

                BottomControlsBar(
                    onGalleryTap: openSystemGallery,
                    onFlipTap: {}
                )
            }
            .ignoresSafeArea(edges: .bottom)

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
        }
        .task { await viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        .confirmationDialog(
            "가이드라인 추가",
            isPresented: $viewModel.state.isAddGuideSheetPresented,
            titleVisibility: .visible
        ) {
            Button("가이드 사진 찍기") { onGuideCaptureRequested() }
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
                Task { await viewModel.confirmDelete() }
            }
        } message: {
            Text("삭제한 가이드라인은 복구할 수 없어요.")
        }
    }

    private var emptyStateHint: some View {
        VStack(spacing: 4) {
            Text("첫 가이드라인을 추가해보세요")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
            Text("좋아하는 사진의 구도를 카메라에 띄울 수 있어요")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))
        }
    }

    private func openSystemGallery() {
        if let url = URL(string: "photos-redirect://"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
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
