import SwiftUI
import PhotosUI

struct CameraView: View {
    @StateObject private var viewModel: CameraViewModel
    @State private var pickedItem: PhotosPickerItem? = nil
    private let onAddGuideTapped: () -> Void
    private let onGuideCaptureRequested: () -> Void
    private let onGuideImagePicked: (Data) -> Void

    init(
        viewModel: CameraViewModel? = nil,
        onAddGuideTapped: @escaping () -> Void = {},
        onGuideCaptureRequested: @escaping () -> Void,
        onGuideImagePicked: @escaping (Data) -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: viewModel ?? AppDIContainer.shared.makeCameraViewModel()
        )
        self.onAddGuideTapped = onAddGuideTapped
        self.onGuideCaptureRequested = onGuideCaptureRequested
        self.onGuideImagePicked = onGuideImagePicked
    }

    var body: some View {
        ZStack {
            AppColors.cameraBlack.ignoresSafeArea()

            if viewModel.state.status != .denied {
                CameraPreviewView(session: viewModel.session)
                    .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                plusStrip
                ShutterButton(
                    isCapturing: viewModel.state.status == .capturing,
                    action: { Task { await viewModel.capture() } }
                )
                .padding(.top, AppSpacing.gapM)
                .padding(.bottom, AppMetrics.Camera.shutterBottomOffset)
                bottomBar
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
                savedToast
                    .transition(.opacity)
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
    }

    private var plusStrip: some View {
        HStack {
            Spacer()
            Button(action: { viewModel.presentAddGuideSheet() }) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.thumb)
                        .fill(Color.white.opacity(0.18))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.thumb)
                                .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                        )
                        .frame(width: 56, height: 56)
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.trailing, AppSpacing.edge)
        }
        .frame(height: 78)
    }

    private var bottomBar: some View {
        Color.black
            .frame(height: AppMetrics.Camera.controlsHeight)
            .overlay(alignment: .top) {
                Color.white.opacity(0.06).frame(height: 0.5)
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
