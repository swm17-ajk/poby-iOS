import SwiftUI
import PhotosUI

struct MacCameraFallbackView: View {
    @ObservedObject var viewModel: CameraViewModel
    @State private var pickedItem: PhotosPickerItem?

    let onGuideCaptureRequested: () -> Void
    let onGuideImagePicked: (Data) -> Void
    let onGalleryTap: () -> Void

    var body: some View {
        let palette = viewModel.palette

        ZStack {
            palette.surface.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                GuideListStrip(
                    guides: viewModel.guides,
                    selectedGuideId: viewModel.selectedGuide?.id,
                    thumbnailURL: { viewModel.thumbnailURL(for: $0) },
                    palette: palette,
                    onTapGuide: { viewModel.selectGuide($0) },
                    onLongPressGuide: { viewModel.requestDelete($0) },
                    onTapPlus: { viewModel.presentAddGuideSheet() }
                )

                ShutterButton(matched: false, isCapturing: false, palette: palette, action: {})
                    .padding(.bottom, AppMetrics.Camera.shutterBottomOffset)

                BottomControlsBar(
                    onGalleryTap: onGalleryTap,
                    onFlipTap: nil,
                    palette: palette
                )
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .task { await viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        .onAppear {
            if AppDIContainer.shared.makeSettingsStore().consumePendingOpenAddGuideDialog() {
                viewModel.presentAddGuideSheet()
            }
        }
        .confirmationDialog(
            "가이드라인 추가",
            isPresented: $viewModel.state.isAddGuideSheetPresented,
            titleVisibility: .visible
        ) {
            Button("가이드 사진 찍기") { onGuideCaptureRequested() }
            Button("갤러리에서 등록") { viewModel.presentPhotoPicker() }
            Button("취소", role: .cancel) {}
        }
        .photosPicker(
            isPresented: $viewModel.state.isPhotoPickerPresented,
            selection: $pickedItem,
            matching: .images
        )
        .onChange(of: pickedItem) { _, newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self) {
                    onGuideImagePicked(data)
                }
                pickedItem = nil
            }
        }
        .alert(
            "가이드라인을 삭제할까요?",
            isPresented: Binding(
                get: { viewModel.guideToDelete != nil },
                set: { if !$0 { viewModel.cancelDelete() } }
            )
        ) {
            Button("취소", role: .cancel) { viewModel.cancelDelete() }
            Button("삭제", role: .destructive) {
                if let guide = viewModel.guideToDelete {
                    Task { await viewModel.confirmDelete(guide) }
                }
            }
        } message: {
            Text("삭제한 가이드라인은 복구할 수 없어요.")
        }
    }
}
