import SwiftUI

struct OnboardingView: View {
    let skipDetail: Bool
    let analytics: AnalyticsService
    let onComplete: () -> Void

    @State private var step: TutorialStep = .landing

    var body: some View {
        ZStack {
            AppTheme.warm.palette.surface.ignoresSafeArea()

            switch step {
            case .landing:
                landingScreen
                    .transition(.opacity)
            case .whyPoby:
                whyPobyScreen
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }

            if step == .whyPoby {
                VStack {
                    Spacer()
                    Button(action: onComplete) {
                        Text("tutorial_start_button")
                            .font(Font.pretendard(.bold, size: 18))
                            .foregroundStyle(AppColors.mintDeep)
                            .frame(maxWidth: .infinity)
                            .frame(height: AppMetrics.Onboarding.ctaHeight)
                            .background(
                                AppColors.mint,
                                in: RoundedRectangle(cornerRadius: AppMetrics.Onboarding.ctaCornerRadius)
                            )
                            .appShadow(AppShadow.mintGlow)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, AppSpacing.edge)
                    .padding(.bottom, AppSpacing.groupM)
                }
            }
        }
        .task {
            analytics.log(
                AnalyticsEvent.tutorialStepViewed,
                properties: ["step": TutorialStep.landing.analyticsValue]
            )
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            guard step == .landing else { return }
            if skipDetail {
                onComplete()
            } else {
                withAnimation(.easeOut(duration: 0.35)) {
                    step = .whyPoby
                }
                analytics.log(
                    AnalyticsEvent.tutorialStepViewed,
                    properties: ["step": TutorialStep.whyPoby.analyticsValue]
                )
            }
        }
    }

    private var landingScreen: some View {
        VStack(spacing: AppMetrics.Onboarding.landingSpacing) {
            ViewfinderMark()
            VStack(spacing: AppSpacing.gapM) {
                PobyWordmark()
                Text("tutorial_landing_tagline")
                    .font(Font.pretendard(.medium, size: 14))
                    .foregroundStyle(AppColors.inkTertiary)
            }
        }
    }

    private var whyPobyScreen: some View {
        VStack(spacing: 0) {
            Spacer(minLength: AppMetrics.Onboarding.topSpacerMin)

            Text("tutorial_why_label")
                .font(Font.pretendard(.bold, size: 11))
                .foregroundStyle(AppColors.inkTertiary)
                .tracking(2)
                .padding(.bottom, AppMetrics.Onboarding.eyebrowBottomPadding)

            VStack(spacing: 4) {
                Text("tutorial_why_question_first_line")
                Text("tutorial_why_question_second_line")
            }
            .font(Font.pretendard(.bold, size: 24))
            .foregroundStyle(AppColors.inkSecondary)
            .multilineTextAlignment(.center)
            .lineSpacing(AppMetrics.Onboarding.headlineLineSpacing)
            .padding(.horizontal, AppSpacing.edge)

            Spacer(minLength: AppMetrics.Onboarding.sectionSpacerMin)

            demoCard

            Spacer(minLength: AppMetrics.Onboarding.sectionSpacerMin)

            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    Text("tutorial_why_now_prefix")
                    Text(verbatim: "poby")
                        .padding(.horizontal, 4)
                        .background(alignment: .bottom) {
                            AppColors.mint
                                .frame(height: AppMetrics.Onboarding.highlightHeight)
                        }
                    Text("tutorial_why_now_suffix")
                }
                .font(Font.pretendard(.extraBold, size: 22))
                .foregroundStyle(AppColors.inkPrimary)

                Text("tutorial_why_subtitle")
                    .font(Font.pretendard(.regular, size: 13))
                    .foregroundStyle(AppColors.inkTertiary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(AppMetrics.Onboarding.bodyLineSpacing)
            }
            .padding(.horizontal, AppSpacing.edge)

            Spacer(minLength: AppMetrics.Onboarding.bottomSpacerMin)
        }
    }

    private var demoCard: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: AppMetrics.Onboarding.demoCardCornerRadius)
                .fill(Color.white)
                .appShadow(AppShadow.card)

            ZStack {
                Image("OnboardingPerson")
                    .resizable()
                    .scaledToFill()

                Image("OnboardingPersonOutline")
                    .resizable()
                    .scaledToFill()
                    .shadow(color: AppColors.mint.opacity(0.5), radius: 5)

                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark")
                            Text("tutorial_match_pill")
                        }
                        .font(AppTypography.pill)
                        .foregroundStyle(AppColors.mintDeep)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppColors.mint, in: Capsule())
                        .padding(AppMetrics.Onboarding.matchPillPadding)
                    }
                    Spacer()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.Onboarding.demoImageCornerRadius))
            .padding(AppMetrics.Onboarding.demoImageInset)
        }
        .frame(maxWidth: AppMetrics.Onboarding.demoCardMaxWidth)
        .aspectRatio(AppMetrics.Onboarding.demoCardAspectRatio, contentMode: .fit)
    }
}

private enum TutorialStep {
    case landing
    case whyPoby

    var analyticsValue: String {
        switch self {
        case .landing: return "landing"
        case .whyPoby: return "why_poby"
        }
    }
}

private struct ViewfinderMark: View {
    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                CornerMark()
                    .rotationEffect(.degrees(Double(index) * 90))
            }
        }
        .frame(width: AppMetrics.Onboarding.viewfinderSize, height: AppMetrics.Onboarding.viewfinderSize)
        .foregroundStyle(AppColors.mint)
    }
}

private struct CornerMark: View {
    var body: some View {
        VStack {
            HStack {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: AppMetrics.Onboarding.cornerMarkSize))
                    path.addLine(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: AppMetrics.Onboarding.cornerMarkSize, y: 0))
                }
                .stroke(style: StrokeStyle(
                    lineWidth: AppMetrics.Onboarding.cornerMarkLineWidth,
                    lineCap: .round,
                    lineJoin: .round
                ))
                .frame(
                    width: AppMetrics.Onboarding.cornerMarkSize,
                    height: AppMetrics.Onboarding.cornerMarkSize
                )
                Spacer()
            }
            Spacer()
        }
    }
}

private struct PobyWordmark: View {
    var body: some View {
        Text(verbatim: "poby")
            .font(Font.pretendard(.extraBold, size: 44))
            .foregroundStyle(AppColors.inkPrimary)
    }
}

#if DEBUG
#Preview {
    OnboardingView(skipDetail: false, analytics: AmplitudeAnalyticsService(), onComplete: {})
}
#endif
