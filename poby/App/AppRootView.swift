import SwiftUI
import Photos

struct AppRootView: View {
    @StateObject private var router = AppRouter()
    @State private var settings = UserDefaultsAppSettingsStore().load()
    @State private var hasEnteredCamera = UserDefaultsAppSettingsStore().load().hasCompletedOnboarding
    private let analytics = AppDIContainer.shared.makeAnalyticsService()

    var body: some View {
        Group {
            if hasEnteredCamera {
                NavigationStack(path: $router.path) {
                    CameraView(
                        onGuideCaptureRequested: { router.push(.guideCapture) },
                        onGuideImagePicked: { data in router.push(.guideExtraction(imageData: data)) },
                        onGalleryTap: { router.push(.gallery) }
                    )
                    .navigationDestination(for: AppRoute.self) { route in
                        switch route {
                        case .gallery:
                            GalleryView(analytics: analytics, onBack: { router.pop() })
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
            } else {
                OnboardingView(skipDetail: settings.hasSeenTutorialDetail, analytics: analytics) {
                    analytics.log(AnalyticsEvent.tutorialCompleted)
                    AppDIContainer.shared.makeSettingsStore().completeTutorial()
                    settings = AppDIContainer.shared.makeSettingsStore().load()
                    hasEnteredCamera = true
                }
            }
        }
    }
}

#Preview {
    AppRootView()
}

struct GalleryView: View {
    let analytics: AnalyticsService
    let onBack: () -> Void

    @State private var assets: [PHAsset] = []
    @State private var selectedIndex: Int?
    @State private var assetToDelete: PHAsset?
    @State private var settings = UserDefaultsAppSettingsStore().load()
    @State private var hasLoggedView = false

    var body: some View {
        let palette = settings.selectedTheme.palette
        ZStack {
            palette.surface.ignoresSafeArea()

            if let selectedIndex, !assets.isEmpty {
                PhotoPagerView(
                    assets: assets,
                    initialIndex: selectedIndex,
                    onClose: { self.selectedIndex = nil },
                    onDeleteRequest: { asset in
                        analytics.log(AnalyticsEvent.galleryPhotoDeleteRequested)
                        assetToDelete = asset
                    },
                    palette: palette
                )
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: AppMetrics.iconM, weight: .semibold))
                                .foregroundStyle(palette.onSurface)
                                .frame(width: AppMetrics.iconButtonLarge, height: AppMetrics.iconButtonLarge)
                        }
                        .buttonStyle(.plain)

                        Text("갤러리")
                            .font(AppTypography.hintLarge)
                            .foregroundStyle(palette.onSurface)
                        Spacer()
                    }
                    .padding(.horizontal, AppSpacing.gapXXS)
                    .padding(.top, AppSpacing.gapS)

                    if assets.isEmpty {
                        Spacer()
                        Text("저장된 사진이 없어요")
                            .font(AppTypography.body)
                            .foregroundStyle(palette.onSurfaceMuted)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVGrid(
                                columns: Array(repeating: GridItem(.flexible(), spacing: AppMetrics.borderHairline), count: 3),
                                spacing: AppMetrics.borderHairline
                            ) {
                                ForEach(Array(assets.enumerated()), id: \.element.localIdentifier) { index, asset in
                                    PhotoThumbnail(
                                        asset: asset,
                                        aspectRatio: settings.selectedAspectRatio.value,
                                        palette: palette
                                    )
                                    .onTapGesture {
                                        analytics.log(AnalyticsEvent.galleryPhotoOpened)
                                        selectedIndex = index
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .task { await loadPhotos() }
        .onAppear { settings = AppDIContainer.shared.makeSettingsStore().load() }
        .alert(
            "사진을 삭제할까요?",
            isPresented: Binding(
                get: { assetToDelete != nil },
                set: { if !$0 { assetToDelete = nil } }
            )
        ) {
            Button("취소", role: .cancel) { assetToDelete = nil }
            Button("삭제", role: .destructive) {
                if let assetToDelete {
                    Task { await delete(assetToDelete) }
                }
            }
        } message: {
            Text("삭제한 사진은 복구할 수 없어요.")
        }
    }

    private func loadPhotos() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else {
            assets = []
            return
        }
        let loaded = Self.fetchPobyAssets()
        await MainActor.run {
            assets = loaded
            if !hasLoggedView {
                analytics.log(
                    AnalyticsEvent.galleryViewed,
                    properties: ["photo_count": loaded.count]
                )
                hasLoggedView = true
            }
        }
    }

    private func delete(_ asset: PHAsset) async {
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets([asset] as NSArray)
            }
            assetToDelete = nil
            await loadPhotos()
            analytics.log(AnalyticsEvent.galleryPhotoDeleted)
            if let selectedIndex, selectedIndex >= assets.count {
                self.selectedIndex = assets.isEmpty ? nil : assets.count - 1
            }
        } catch {
            assetToDelete = nil
        }
    }

    private static func fetchPobyAssets() -> [PHAsset] {
        guard let album = CameraService.fetchAlbum(named: "poby") else { return [] }
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(in: album, options: options)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in assets.append(asset) }
        return assets
    }
}

private struct PhotoThumbnail: View {
    let asset: PHAsset
    let aspectRatio: CGFloat
    let palette: AppPalette

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            palette.surfaceMuted
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipped()
        .task(id: asset.localIdentifier) {
            image = await requestImage(asset: asset, targetSize: AppMetrics.Gallery.thumbnailRequestSize)
        }
    }
}

private struct PhotoPagerView: View {
    let assets: [PHAsset]
    let initialIndex: Int
    let onClose: () -> Void
    let onDeleteRequest: (PHAsset) -> Void
    let palette: AppPalette

    @State private var selectedIndex: Int

    init(
        assets: [PHAsset],
        initialIndex: Int,
        onClose: @escaping () -> Void,
        onDeleteRequest: @escaping (PHAsset) -> Void,
        palette: AppPalette
    ) {
        self.assets = assets
        self.initialIndex = initialIndex
        self.onClose = onClose
        self.onDeleteRequest = onDeleteRequest
        self.palette = palette
        _selectedIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack {
            TabView(selection: $selectedIndex) {
                ForEach(Array(assets.enumerated()), id: \.element.localIdentifier) { index, asset in
                    PhotoPage(asset: asset)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: AppMetrics.iconM, weight: .semibold))
                            .foregroundStyle(palette.onSurface)
                            .frame(width: AppMetrics.iconButtonLarge, height: AppMetrics.iconButtonLarge)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button(action: { onDeleteRequest(assets[selectedIndex]) }) {
                        Image(systemName: "trash")
                            .font(.system(size: AppMetrics.iconM, weight: .semibold))
                            .foregroundStyle(palette.onSurface)
                            .frame(width: AppMetrics.iconButtonLarge, height: AppMetrics.iconButtonLarge)
                    }
                    .buttonStyle(.plain)
                }
                .padding(AppSpacing.gapXS)
                Spacer()
            }
        }
        .background(palette.surface.ignoresSafeArea())
    }
}

private struct PhotoPage: View {
    let asset: PHAsset
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: asset.localIdentifier) {
            image = await requestImage(asset: asset, targetSize: AppMetrics.Gallery.detailRequestSize)
        }
    }
}

private func requestImage(asset: PHAsset, targetSize: CGSize) async -> UIImage? {
    await withCheckedContinuation { continuation in
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            continuation.resume(returning: image)
        }
    }
}
