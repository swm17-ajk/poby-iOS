import SwiftUI

struct GuideCaptureView: View {
    @StateObject private var viewModel: GuideCaptureViewModel
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
        ZStack {
            AppColors.cameraBlack.ignoresSafeArea()

            if viewModel.state.status == .ready || viewModel.state.status == .capturing {
                CameraPreviewView(session: viewModel.session)
                    .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 0)
                ShutterButton(
                    isCapturing: viewModel.state.status == .capturing,
                    action: { Task { await viewModel.capture() } }
                )
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

            if let data = viewModel.state.capturedImage {
                recaptureCard(imageData: data)
            }
        }
        .navigationBarBackButtonHidden(true)
        .task { await viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
    }

    private var topBar: some View {
        HStack {
            Button(action: onCancel) {
                Text("취소")
                    .font(AppTypography.body)
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.gapM)
                    .padding(.vertical, AppSpacing.gapXS)
                    .background(.black.opacity(0.35), in: Capsule())
            }
            Spacer()
        }
        .padding(.horizontal, AppSpacing.edge)
        .padding(.top, AppSpacing.gapS)
    }

    private var bottomBar: some View {
        Color.black
            .frame(height: AppMetrics.Camera.controlsHeight)
            .overlay(alignment: .top) {
                Color.white.opacity(0.06).frame(height: 0.5)
            }
    }

    private func recaptureCard(imageData: Data) -> some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()

            VStack(spacing: AppSpacing.gapM) {
                if let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 400)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                }

                Text("이 사진으로 가이드라인을 만들까요?")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.inkPrimary)

                HStack(spacing: AppSpacing.gapS) {
                    Button(action: { viewModel.discardCaptured() }) {
                        Text("재촬영")
                            .font(AppTypography.buttonSecondary)
                            .foregroundStyle(AppColors.inkPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.gapM)
                            .background(AppColors.Warm.paper2, in: RoundedRectangle(cornerRadius: AppRadius.row))
                    }
                    Button(action: { onConfirmed(imageData) }) {
                        Text("완료")
                            .font(AppTypography.buttonPrimary)
                            .foregroundStyle(AppColors.mintDeep)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.gapM)
                            .background(AppColors.mint, in: RoundedRectangle(cornerRadius: AppRadius.row))
                            .appShadow(AppShadow.mintGlow)
                    }
                }
            }
            .padding(AppSpacing.groupS)
            .background(AppColors.Warm.paper, in: RoundedRectangle(cornerRadius: AppRadius.sheet))
            .padding(.horizontal, AppSpacing.edge)
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
}
