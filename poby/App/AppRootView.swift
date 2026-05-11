import SwiftUI

struct AppRootView: View {
    @StateObject private var router = AppRouter()

    var body: some View {
        NavigationStack(path: $router.path) {
            CameraView(
                onGuideCaptureRequested: { router.push(.guideCapture) },
                onGuideImagePicked: { data in router.push(.guideExtraction(imageData: data)) }
            )
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .guideCapture:
                    GuideCaptureView(
                        onCancel: { router.popToRoot() },
                        onConfirmed: { data in router.push(.guideExtraction(imageData: data)) }
                    )
                case .guideExtraction(let data):
                    GuideExtractionView(
                        viewModel: AppDIContainer.shared.makeGuideExtractionViewModel(imageData: data),
                        onCancel: { router.popToRoot() },
                        onDone: { router.popToRoot() }
                    )
                }
            }
        }
    }
}

#Preview {
    AppRootView()
}
