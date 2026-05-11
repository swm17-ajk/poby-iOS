import Foundation
import SwiftUI

enum AppRoute: Hashable {
    case guideCapture
    case guideExtraction(imageData: Data)
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var path: [AppRoute] = []

    func push(_ route: AppRoute) {
        path.append(route)
    }

    func popToRoot() {
        path.removeAll()
    }
}
