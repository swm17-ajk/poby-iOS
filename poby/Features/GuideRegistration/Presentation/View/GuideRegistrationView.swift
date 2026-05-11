import SwiftUI

struct GuideRegistrationView: View {
    @StateObject private var viewModel: GuideRegistrationViewModel
    private let onDone: () -> Void

    init(
        viewModel: GuideRegistrationViewModel? = nil,
        onDone: @escaping () -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: viewModel ?? AppDIContainer.shared.makeGuideRegistrationViewModel()
        )
        self.onDone = onDone
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Guide Registration (TODO)")
            Button("완료", action: onDone)
        }
        .navigationTitle("가이드 추가")
    }
}

#Preview {
    NavigationStack {
        GuideRegistrationView(onDone: {})
    }
}
