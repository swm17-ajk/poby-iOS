import SwiftUI

struct PlusThumb: View {
    let pulse: Bool
    let onTap: () -> Void

    @State private var pulsing = false

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.thumb)
                    .fill(Color.white.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.thumb)
                            .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                    )
                    .frame(width: 56, height: 56)

                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(pulse && pulsing ? 1.04 : 1.0)
            .shadow(
                color: pulse && pulsing ? Color.white.opacity(0.18) : .clear,
                radius: 8
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            guard pulse else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
        .onChange(of: pulse) { _, newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    pulsing = true
                }
            } else {
                pulsing = false
            }
        }
    }
}
