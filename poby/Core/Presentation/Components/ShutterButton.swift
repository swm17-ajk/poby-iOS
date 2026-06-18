import SwiftUI

struct ShutterButton: View {
    var matched: Bool = false
    var isCapturing: Bool = false
    var palette: AppPalette = AppTheme.dark.palette
    let action: () -> Void

    var body: some View {
        let activeColor = matched ? AppColors.mint : palette.onSurface
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(
                        activeColor,
                        lineWidth: AppMetrics.Camera.shutterBorderWidth
                    )
                    .frame(
                        width: AppMetrics.Camera.shutterSize,
                        height: AppMetrics.Camera.shutterSize
                    )

                Circle()
                    .fill(activeColor)
                    .frame(
                        width: AppMetrics.Camera.shutterInnerSize,
                        height: AppMetrics.Camera.shutterInnerSize
                    )
                    .scaleEffect(isCapturing ? 0.85 : 1)
                    .animation(.easeOut(duration: 0.12), value: isCapturing)
            }
            .appShadow(matched ? AppShadow.mintGlow : AppShadow.shutter)
        }
        .buttonStyle(.plain)
        .disabled(isCapturing)
    }
}

#Preview {
    ZStack {
        AppColors.cameraBlack.ignoresSafeArea()
        VStack(spacing: 32) {
            ShutterButton(matched: false, action: {})
            ShutterButton(matched: true, action: {})
            ShutterButton(matched: false, isCapturing: true, action: {})
        }
    }
}
