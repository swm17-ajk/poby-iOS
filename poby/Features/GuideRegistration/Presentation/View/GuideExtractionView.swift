import SwiftUI

struct GuideExtractionView: View {
    @StateObject private var viewModel: GuideExtractionViewModel
    private let onCancel: () -> Void
    private let onDone: () -> Void

    init(
        imageData: Data,
        onCancel: @escaping () -> Void,
        onDone: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: GuideExtractionViewModel(imageData: imageData))
        self.onCancel = onCancel
        self.onDone = onDone
    }

    var body: some View {
        ZStack {
            AppColors.Warm.paper.ignoresSafeArea()

            VStack(spacing: AppSpacing.groupS) {
                topBar
                Spacer(minLength: 0)

                if let uiImage = UIImage(data: viewModel.state.sourceImage) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                        .padding(.horizontal, AppSpacing.edge)
                }

                Text("Stage 3에서 실루엣을 추출해 가이드라인으로 만듭니다.")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.inkSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.groupM)

                Spacer(minLength: 0)
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private var topBar: some View {
        HStack {
            Button("취소", action: onCancel)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.inkPrimary)
            Spacer()
            Text("가이드라인 추출")
                .font(AppTypography.title)
                .foregroundStyle(AppColors.inkPrimary)
            Spacer()
            Button("완료", action: onDone)
                .font(AppTypography.buttonPrimary)
                .foregroundStyle(AppColors.Warm.doneActive)
        }
        .padding(.horizontal, AppSpacing.edge)
        .padding(.top, AppSpacing.gapS)
    }
}
