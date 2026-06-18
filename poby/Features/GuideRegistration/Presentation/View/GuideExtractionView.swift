import SwiftUI

struct GuideExtractionView: View {
    @StateObject private var viewModel: GuideExtractionViewModel
    @State private var settings = UserDefaultsAppSettingsStore().load()
    private let onCancel: () -> Void
    private let onDone: () -> Void

    init(
        viewModel: GuideExtractionViewModel,
        onCancel: @escaping () -> Void,
        onDone: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onCancel = onCancel
        self.onDone = onDone
    }

    var body: some View {
        let palette = settings.selectedTheme.palette

        VStack(spacing: 0) {
            topBar(palette: palette)
            Spacer().frame(height: AppSpacing.edge)
            photoArea(palette: palette)
            Spacer().frame(height: AppSpacing.groupS)
            statusArea(palette: palette)
            Spacer(minLength: 0)
        }
        .background(palette.surface.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .task { await viewModel.extract() }
        .onAppear { settings = AppDIContainer.shared.makeSettingsStore().load() }
    }

    private var sourceImage: UIImage? {
        UIImage(data: viewModel.sourceImageData)
    }

    private var sourceAspectRatio: CGFloat {
        guard let img = sourceImage, img.size.height > 0 else { return 3.0 / 4.0 }
        return img.size.width / img.size.height
    }

    private func topBar(palette: AppPalette) -> some View {
        HStack {
            Button("취소", action: onCancel)
                .font(AppTypography.body)
                .foregroundStyle(palette.onSurface)
            Spacer()
            Text("새 가이드라인")
                .font(AppTypography.hintLarge)
                .foregroundStyle(palette.onSurface)
            Spacer()
            Button(action: { Task { await complete() } }) {
                Text("완료")
                    .font(AppTypography.hintLarge)
                    .foregroundStyle(AppColors.mint.opacity(viewModel.isDoneEnabled ? 1.0 : 0.3))
            }
            .disabled(!viewModel.isDoneEnabled)
        }
        .padding(.horizontal, AppSpacing.edge)
        .frame(height: AppMetrics.Control.buttonHeight)
        .padding(.top, AppSpacing.gapS)
    }

    private func photoArea(palette: AppPalette) -> some View {
        let ratio = successAspectRatio ?? 3.0 / 4.0
        return palette.surfaceMuted
            .aspectRatio(ratio, contentMode: .fit)
            .overlay {
                if let uiImage = sourceImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                }
            }
            .overlay {
                switch viewModel.state {
                case .loading:
                    loadingSpinner
                case .success(let silhouette):
                    SilhouetteOverlay(
                        silhouette: silhouette,
                        color: palette.onSurface,
                        lineWidth: AppMetrics.Camera.guideLineWidth,
                        glow: false
                    )
                case .failure:
                    EmptyView()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .padding(.horizontal, AppSpacing.edge)
    }

    private var successAspectRatio: CGFloat? {
        if case .success = viewModel.state {
            return sourceAspectRatio
        }
        return nil
    }

    private var loadingSpinner: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius.row)
                .fill(Color.black.opacity(0.35))
                .frame(
                    width: AppMetrics.GuideExtraction.loadingBoxSize,
                    height: AppMetrics.GuideExtraction.loadingBoxSize
                )
            CircularSpinner(
                size: AppMetrics.GuideExtraction.spinnerSize,
                lineWidth: AppMetrics.GuideExtraction.spinnerLineWidth,
                color: AppColors.mint
            )
        }
    }

    private func statusArea(palette: AppPalette) -> some View {
        Group {
            switch viewModel.state {
            case .loading:
                VStack(spacing: AppSpacing.gapM) {
                AnimatedProgressBar(targetProgress: 0.9, color: AppColors.mint)
                    .frame(height: AppMetrics.GuideExtraction.progressHeight)
                    .clipShape(Capsule())
                Text("인물을 감지하고 있어요")
                    .font(AppTypography.body)
                    .foregroundStyle(palette.onSurfaceMuted)
                }
                .padding(.horizontal, AppSpacing.edge)
            case .success:
                Text("가이드라인이 추출되었어요")
                    .font(AppTypography.body)
                    .foregroundStyle(palette.onSurfaceMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, AppSpacing.groupM)
            case .failure(let message):
                VStack(spacing: AppSpacing.gapM) {
                    Text(message)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.danger)
                        .multilineTextAlignment(.center)
                    Button(action: { Task { await viewModel.extract() } }) {
                        Text("다시 시도")
                            .font(AppTypography.buttonPrimary)
                            .foregroundStyle(AppColors.mint)
                    }
                }
                .padding(.horizontal, AppSpacing.groupM)
            }
        }
    }

    private func complete() async {
        do {
            _ = try await viewModel.save()
            onDone()
        } catch {
            // save 실패는 드물지만 발생 시 무시 (저장 실패 표시는 향후)
        }
    }
}

private struct CircularSpinner: View {
    let size: CGFloat
    let lineWidth: CGFloat
    let color: Color
    @State private var rotation: Double = 0

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

private struct AnimatedProgressBar: View {
    let targetProgress: Double
    let color: Color
    @State private var progress: Double = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.18))
                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * progress)
                    .shadow(color: color.opacity(0.7), radius: 6)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.5)) {
                progress = targetProgress
            }
        }
    }
}

#if DEBUG

private func makeSamplePhotoData() -> Data {
    let size = CGSize(width: 600, height: 800)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.jpegData(withCompressionQuality: 0.8) { ctx in
        let cg = ctx.cgContext
        let cs = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(
            colorsSpace: cs,
            colors: [
                UIColor(red: 0.85, green: 0.78, blue: 0.6, alpha: 1).cgColor,
                UIColor(red: 0.45, green: 0.32, blue: 0.2, alpha: 1).cgColor
            ] as CFArray,
            locations: [0, 1]
        )!
        cg.drawLinearGradient(
            gradient,
            start: .zero,
            end: CGPoint(x: 0, y: size.height),
            options: []
        )
    }
}

private func mockSilhouette() -> GuideSilhouette {
    GuideSilhouette(
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
    )
}

#Preview("로딩") {
    GuideExtractionView(
        viewModel: GuideExtractionViewModel(
            previewState: .loading,
            imageData: makeSamplePhotoData()
        ),
        onCancel: {},
        onDone: {}
    )
}

#Preview("성공") {
    GuideExtractionView(
        viewModel: GuideExtractionViewModel(
            previewState: .success(silhouette: mockSilhouette()),
            imageData: makeSamplePhotoData()
        ),
        onCancel: {},
        onDone: {}
    )
}

#Preview("실패") {
    GuideExtractionView(
        viewModel: GuideExtractionViewModel(
            previewState: .failure(message: "인물을 찾지 못했어요"),
            imageData: makeSamplePhotoData()
        ),
        onCancel: {},
        onDone: {}
    )
}

#endif
