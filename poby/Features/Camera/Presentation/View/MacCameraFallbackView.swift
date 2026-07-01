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
            "camera_add_guide_title",
            isPresented: $viewModel.state.isAddGuideSheetPresented,
            titleVisibility: .visible
        ) {
            Button("camera_add_guide_take_photo") { onGuideCaptureRequested() }
            Button("camera_add_guide_from_gallery") { viewModel.presentPhotoPicker() }
            Button("common_cancel", role: .cancel) {}
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
            "camera_delete_guide_title",
            isPresented: Binding(
                get: { viewModel.guideToDelete != nil },
                set: { if !$0 { viewModel.cancelDelete() } }
            )
        ) {
            Button("common_cancel", role: .cancel) { viewModel.cancelDelete() }
            Button("common_delete", role: .destructive) {
                if let guide = viewModel.guideToDelete {
                    Task { await viewModel.confirmDelete(guide) }
                }
            }
        } message: {
            Text("camera_delete_guide_message")
        }
    }
}
