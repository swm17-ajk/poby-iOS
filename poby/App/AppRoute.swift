import Foundation
import SwiftUI

enum AppRoute: Hashable {
    case guideRegistration
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var path: [AppRoute] = []
}
