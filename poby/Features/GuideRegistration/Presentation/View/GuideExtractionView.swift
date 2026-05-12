import SwiftUI

struct GuideExtractionView: View {
    @StateObject private var viewModel: GuideExtractionViewModel
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
        ZStack {
            AppColors.Warm.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                photoArea
                Spacer(minLength: 0)
            }
        }
        .navigationBarBackButtonHidden(true)
        .task { await viewModel.extract() }
    }

    private var sourceImage: UIImage? {
        UIImage(data: viewModel.sourceImageData)
    }

    private var sourceAspectRatio: CGFloat {
        guard let img = sourceImage, img.size.height > 0 else { return 3.0 / 4.0 }
        return img.size.width / img.size.height
    }

    private var topBar: some View {
        HStack {
            Button("취소", action: onCancel)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.inkPrimary)
            Spacer()
            Text("새 가이드라인")
                .font(AppTypography.hintLarge)
                .foregroundStyle(AppColors.inkPrimary)
            Spacer()
            Button(action: { Task { await complete() } }) {
                Text("완료")
                    .font(AppTypography.hintLarge)
                    .foregroundStyle(viewModel.isDoneEnabled ? AppColors.Warm.doneActive : AppColors.Warm.doneInactive)
            }
            .disabled(!viewModel.isDoneEnabled)
        }
        .padding(.horizontal, AppSpacing.edge)
        .frame(height: 52)
    }

    private var photoArea: some View {
        Color.black.opacity(0.06)
            .aspectRatio(sourceAspectRatio, contentMode: .fit)
            .overlay {
                if let uiImage = sourceImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            }
            .overlay {
                switch viewModel.state {
                case .loading:
                    loadingOverlay
                case .success(let silhouette):
                    ZStack(alignment: .bottom) {
                        SilhouetteOverlay(silhouette: silhouette, color: .white, lineWidth: 2.5, glow: true)
                        successToast
                    }
                case .failure(let message):
                    failureCard(message)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 26))
            .appShadow(AppShadow.card)
            .padding(.horizontal, AppSpacing.edge)
            .padding(.top, AppSpacing.edge)
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.42)
            VStack(spacing: AppSpacing.groupS) {
                CircularSpinner(size: 48, lineWidth: 3, color: AppColors.mint)
                Text("인물을 감지하고 있어요")
                    .font(Font.pretendard(.semiBold, size: 16))
                    .foregroundStyle(.white)
                AnimatedProgressBar(targetProgress: 0.9, color: AppColors.mint)
                    .frame(width: 220, height: 6)
                Text("분석 중")
                    .font(AppTypography.captionMono)
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
    }

    private var successToast: some View {
        HStack(spacing: AppSpacing.gapXS) {
            Image(systemName: "checkmark")
                .foregroundStyle(AppColors.mint)
                .font(.system(size: 14, weight: .bold))
            Text("가이드라인이 추출되었어요")
                .font(AppTypography.hintSmall)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, AppSpacing.gapM)
        .padding(.vertical, AppSpacing.gapS)
        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: AppRadius.thumb))
        .padding(AppSpacing.gapM)
    }

    private func failureCard(_ message: String) -> some View {
        ZStack {
            Color.black.opacity(0.55)
            VStack(spacing: AppSpacing.gapM) {
                ZStack {
                    Circle()
                        .fill(AppColors.danger.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "exclamationmark")
                        .foregroundStyle(AppColors.danger)
                        .font(.system(size: 20, weight: .bold))
                }
                Text("인물을 찾지 못했어요")
                    .font(Font.pretendard(.bold, size: 17))
                    .foregroundStyle(AppColors.inkPrimary)
                Text("얼굴과 상체가 모두 보이는 사진으로\n다시 시도해주세요.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkTertiary)
                    .multilineTextAlignment(.center)
                Button(action: onCancel) {
                    Text("다른 사진 선택")
                        .font(AppTypography.bodyEmphasis)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.gapM)
                        .background(AppColors.inkPrimary, in: RoundedRectangle(cornerRadius: AppRadius.thumb))
                }
                .padding(.top, AppSpacing.gapXS)
            }
            .padding(AppSpacing.groupS)
            .background(Color.white, in: RoundedRectangle(cornerRadius: AppRadius.card))
            .padding(AppSpacing.groupS)
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
