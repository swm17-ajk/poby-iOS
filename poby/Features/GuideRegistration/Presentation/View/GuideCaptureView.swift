import SwiftUI

struct GuideCaptureView: View {
    @StateObject private var viewModel: GuideCaptureViewModel
    @State private var isFlashOn: Bool = false
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
                    .padding(.top, AppSpacing.gapS)

                Spacer(minLength: 0)

                Text("얼굴 · 상체가 모두 보이도록")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.78))
                    .padding(.bottom, AppSpacing.gapM)

                ShutterButton(
                    isCapturing: viewModel.state.status == .capturing,
                    action: { Task { await viewModel.capture() } }
                )
                .padding(.bottom, AppMetrics.Camera.shutterBottomOffset)

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
                GlassChip {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Text("가이드로 쓸 사진을 찍어주세요")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, AppSpacing.gapM)
                .padding(.vertical, 8)
                .background(Capsule().fill(.black.opacity(0.4)))

            Spacer()

            Button(action: { isFlashOn.toggle() }) {
                GlassChip {
                    Image(systemName: isFlashOn ? "bolt.fill" : "bolt.slash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.edge)
    }

    private func recaptureCard(imageData: Data) -> some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: AppSpacing.gapM) {
                Text("이 사진으로 가이드를 만들까요?")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppColors.inkPrimary)
                Text("완료를 누르면 가이드라인을 추출해요.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkTertiary)
                    .multilineTextAlignment(.center)

                HStack(spacing: AppSpacing.gapS) {
                    Button(action: { viewModel.discardCaptured() }) {
                        Text("재촬영")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppColors.inkPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.gapM)
                            .background(AppColors.Warm.paper2, in: RoundedRectangle(cornerRadius: AppRadius.thumb))
                    }
                    Button(action: { onConfirmed(imageData) }) {
                        Text("완료")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppColors.mintDeep)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.gapM)
                            .background(AppColors.mint, in: RoundedRectangle(cornerRadius: AppRadius.thumb))
                            .appShadow(AppShadow.mintGlow)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.groupS)
            .padding(.top, AppSpacing.groupS)
            .padding(.bottom, AppSpacing.gapM + 4)
            .background(Color.white, in: RoundedRectangle(cornerRadius: AppRadius.card))
            .padding(.horizontal, AppSpacing.groupM)
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
