import SwiftUI

struct AppRootView: View {
    @StateObject private var router = AppRouter()

    var body: some View {
        NavigationStack(path: $router.path) {
            CameraView(onAddGuideTapped: { router.path.append(.guideRegistration) })
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .guideRegistration:
                        GuideRegistrationView(onDone: { router.path.removeLast() })
                    }
                }
        }
    }
}

#Preview {
    AppRootView()
}
