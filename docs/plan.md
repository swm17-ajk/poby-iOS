# poby 구현 계획

`docs/features.md`의 MVP를 iOS로 구현하기 위한 단계별 계획. iOS 첫 프로젝트인 상황을 가정하고, 각 단계마다 새로 익혀야 하는 iOS 개념을 함께 적어둠.

확정된 설계 선택: **가이드라인 = 인물 실루엣 외곽선** (포즈 스켈레톤 아님). Vision의 `VNGeneratePersonSegmentationRequest`를 핵심으로 사용.

---

## 화면 매핑 (`docs/ui.md` 기준)

| Screen | 명칭 | 주로 만들어지는 단계 |
|---|---|---|
| 1 | 카메라 화면 (메인) | 1단계 (코어), 4·5단계 (가이드 오버레이/매칭), 6단계 (부가 버튼 + 가이드 목록) |
| 2 | 가이드라인 추출 화면 | 3단계 |
| 3 | 가이드 사진 촬영 화면 | 2단계 |
| 4 | 갤러리 화면 | 2단계 (`PhotosPicker` 기본 시트로 시작, 필요 시 커스텀 그리드로 교체) |

화면 전환과 컴포넌트 세부는 `docs/ui.md` 참조.

## 실행 순서 메모

단계 번호는 **의존성 순서**다. 실제 작업 순서는 다음과 같이 조정됨:

- 1 → 2 → 3 → 4 → **6** → **5**

이유:
- 5단계(실시간 매칭)는 카메라 라이브 프레임이 필요해 Mac (Designed for iPad) 환경에서 검증 불가. 실기기 iPhone 확보 또는 DEV 모드 도입 시점까지 보류.
- 6단계(UI 마무리)는 카메라 의존 없는 작업이 대부분이라 Mac에서 검증 가능. 먼저 UI 골격을 완성한 다음, 그 위에 매칭 로직을 plug-in 하는 게 자연스러움.
- 두 단계가 손대는 영역은 거의 독립적. 충돌 지점은 Top chrome 중앙(매칭 시 "포즈 매칭" pill ↔ 비매칭 시 비율 토글) 한 곳뿐 — 상호 배타 표시.

---

## 전체 그림: 사용할 iOS 기술

| 영역 | 프레임워크 | 역할 |
|---|---|---|
| UI | SwiftUI | 화면 구성 (기본 템플릿에 이미 잡혀있음) |
| 카메라 | AVFoundation (`AVCaptureSession`) | 실시간 카메라 프리뷰 + 촬영 |
| 인물 감지/실루엣 추출 | Vision (`VNGeneratePersonSegmentationRequest`) | 사람 영역 마스크 생성 |
| 사진 저장/불러오기 | Photos / PhotosPicker | 라이브러리 접근 |
| 데이터 저장 | SwiftData 또는 파일 시스템 | 등록한 가이드라인 영구 저장 |

SwiftUI는 카메라 같은 실시간 처리 UI에 약해서, `UIViewRepresentable`로 UIKit `UIView`를 감싸 SwiftUI 안에 끼워 넣는 패턴을 사용. iOS에서 거의 표준 패턴.

---

## 단계별 계획

### 0단계 — 프로젝트 셋업 (반나절)

- `Info.plist`에 권한 문구 추가 (이 프로젝트는 `GENERATE_INFOPLIST_FILE = YES`이므로 build settings의 `INFOPLIST_KEY_*`로 처리)
  - `NSCameraUsageDescription` (카메라)
  - `NSPhotoLibraryUsageDescription` / `NSPhotoLibraryAddUsageDescription` (앨범 읽기/쓰기)
- 폴더 구조 잡기 (`docs/CLAUDE.md` 기준 — Feature-first MVVM + "비어있는 폴더 미리 만들지 않기"):
  ```
  poby/
    App/
      pobyApp.swift           @main 엔트리
      AppRootView.swift       NavigationStack 라우팅
      AppRoute.swift          AppRoute enum + Router
      AppDIContainer.swift    ViewModel 조립
    Features/
      Camera/
        Presentation/{View, ViewModel, Model}/
      GuideRegistration/
        Presentation/{View, ViewModel, Model}/
  ```
  `Core/` (공유 코드)와 각 Feature 안의 `Domain/`, `Data/`는 실제로 공유·계약이 필요해질 때 (Stage 3 전후) 만든다.
- **배울 것**: Xcode 프로젝트 구조, Info.plist 처리 방식, target/scheme 개념

---

### 1단계 — 카메라 프리뷰 화면 띄우기 (1~2일)

**대응 화면**: Screen 1 (카메라 화면)의 **코어**만.

**목표**: 앱을 열면 카메라 화면이 보이고, 셔터 버튼을 누르면 사진이 찍혀 앨범에 저장된다.

- `AVCaptureSession` 학습 (가장 큰 산)
  - `AVCaptureDevice` → `AVCaptureDeviceInput` → `AVCaptureSession` → `AVCaptureVideoPreviewLayer`
- `UIViewRepresentable`로 프리뷰 레이어를 SwiftUI에서 쓰기
- `AVCapturePhotoOutput`로 셔터 동작
- `PHPhotoLibrary`로 앨범 저장

이 단계가 끝나면 가이드 없이 그냥 카메라 앱이 됨. 일부러 여기까지를 안정화하고 다음으로 넘어갈 것.

**이 단계에서 제외 (→ 6단계로 이연)**: ui.md Screen 1의 갤러리 버튼(좌하단), 전면/후면 전환 버튼(우하단), 화면 비율 조작 버튼(중앙). 1단계는 셔터 + 저장만 안정화한다.

---

### 2단계 — 가이드용 사진 등록 (1~2일)

**대응 화면**: Screen 3 (가이드 사진 촬영) + Screen 4 (갤러리). 둘 다 진입은 Screen 1의 '+' 버튼 모달에서 분기.

**목표**: 라이브러리에서 사진을 고르거나 앱 내에서 촬영해서, 사진 1장을 3단계로 넘긴다. (실제 저장은 3단계 완료 후)

진입 흐름:
- Screen 1의 '+' 버튼 탭 → 모달 팝업 (`.confirmationDialog` 또는 `.sheet`)
  - "가이드 사진 찍기" → Screen 3 (앱 내 촬영)
  - "가이드 사진 등록하기" → Screen 4 (갤러리)

Screen 3 (가이드 사진 촬영):
- 1단계 카메라 흐름 재사용. 단, 저장 대신 메모리에만 들고 있기.
- 촬영 직후 **재촬영 카드 모달** 띄움 — "재촬영" / "완료" 선택
  - 재촬영 → Screen 3 초기 상태로 복귀
  - 완료 → 촬영한 사진을 들고 Screen 2 (추출 화면)로 이동

Screen 4 (갤러리):
- `PhotosPicker` (iOS 16+) 기본 시트로 시작 — 단일 선택, 완료 시 Screen 2로 이동
- ui.md의 커스텀 상단바(취소/완료 버튼)가 필요하면 `PHPickerViewController` 또는 `Photos` 프레임워크로 자체 그리드 구현 (MVP에서는 PhotosPicker로 충분)

`Guide` 모델 정의 (Stage 3에서 silhouette 추가될 자리 마련):
- `id`, `sourceImagePath`, `thumbnailPath` (목록 가로 스크롤용 캐시), `createdAt`, `silhouettePath` (3단계에서 채움)
- 저장은 처음엔 그냥 **Documents 디렉터리에 파일로** 두는 게 가장 단순. SwiftData는 나중에 도입해도 늦지 않음.

폴더 구조 영향: `Features/GuideRegistration/Presentation/View/` 안에 View가 늘어남 — `GuideCaptureView`(Screen 3), `GuideExtractionView`(Screen 2, Stage 3에서 추가). PhotosPicker는 별도 View 안 만들고 Camera 쪽 ViewModel에서 직접 호출해도 됨.

---

### 3단계 — 사진에서 실루엣 추출 (2~3일, 핵심 기술 산)

**대응 화면**: Screen 2 (가이드라인 추출 화면).

**목표**: 2단계에서 받은 사진을 띄워놓고, 사람 영역에서 외곽선을 뽑아 사진 위에 흰색 선으로 미리보기. 완료 시 `Guide`로 저장.

Vision 처리:
- `VNGeneratePersonSegmentationRequest` 실행 → 마스크 `CVPixelBuffer` 획득
- 마스크에서 외곽선(contour) 뽑기 — 두 가지 옵션:
  - (a) `VNDetectContoursRequest`를 마스크 위에 한 번 더 돌려서 윤곽 경로를 받아내기 → `CGPath`로 변환해 저장 (추천: 깔끔하고 가벼움)
  - (b) 마스크 이미지를 그대로 반투명 오버레이로 저장
- 결과를 `Guide.silhouettePath`에 저장

화면 상태(ViewState):
- **로딩 상태** — 화면 중단 프로세스 바 + 로딩 애니메이션, 완료 버튼 비활성
- **추출 성공 상태** — 로딩 UI 사라지고 사진 위에 흰색 선 오버레이, 완료 버튼 활성
- **추출 실패 상태** — 에러 메시지 ("인물을 인식할 수 없어요"), 완료 버튼 비활성 유지 (features.md 3-1번)

상단바 버튼 분기 (ui.md):
- **완료** (우측, 추출 성공 시만 활성) → 추출된 가이드라인 저장 → Screen 1으로 복귀하면서 **새 가이드가 자동 선택·적용된 상태**
- **취소** (좌측) → 추출 데이터 폐기 → Screen 1으로 복귀하면서 **아무 가이드도 적용 안 된 상태**

이 두 복귀 시 상태 차이를 `AppRouter` 또는 Camera ViewModel에 전달하는 인터페이스를 설계해야 함.

iOS 처음이라면 가장 어려운 구간. Apple의 Vision 샘플 코드와 personSegmentation 관련 WWDC 세션 참고. 

폴더 구조 영향: Vision 처리 코드가 두 군데(Stage 3 추출 + Stage 5 실시간 매칭)에서 공유되므로 `Core/Data/Services/VisionService.swift`를 이때 만든다. `Guide` 모델·저장소도 두 Feature에서 쓰이므로 `Core/Domain/Entities/Guide.swift` + `Core/Domain/Repositories/GuideRepositoryProtocol.swift` + `Core/Data/Repositories/FileGuideRepository.swift`로 승격.

---

### 4단계 — 카메라 위에 가이드 오버레이 그리기 (1일)

**목표**: 정적으로라도, 선택한 가이드의 외곽선이 카메라 프리뷰 위에 흰색으로 떠 있다.

- SwiftUI `ZStack`으로 카메라 프리뷰 + 오버레이 레이어 쌓기
- 오버레이는 `Canvas`로 `CGPath` 그리기 (`SilhouetteOverlay` 컴포넌트)
- **가이드 사진 비율 vs 카메라 비율 처리** — 두 비율이 다르므로 그대로 매핑하면 실루엣이 찌그러짐. 해결:
  - `Guide` 모델에 `sourceAspectRatio: Double?` 저장 (저장 시 `UIImage` 크기에서 계산)
  - 오버레이 렌더 시 `.aspectRatio(sourceAspectRatio, contentMode: .fit)` 모디파이어로 letterbox 처리 → 원본 비율 유지, 화면이 더 길면 상하/좌우에 빈 공간
- `allowsHitTesting(false)`로 터치는 셔터·'+' 버튼에 그대로 전달

---

### 5단계 — 실시간 매칭 판정 & 색 변경 (2~3일, 두 번째 산)

**목표**: 카메라 안에 들어온 사람이 가이드와 비슷한 위치/크기/포즈로 들어오면 라인이 민트색으로 변경.

- `AVCaptureVideoDataOutput`로 실시간 프레임 받기 (30fps 전부 처리하면 무거우니 N프레임마다 처리)
- 각 프레임에 `VNGeneratePersonSegmentationRequest` 적용 (정확도 모드: `.balanced` 권장)
- **비율 정규화 (4단계와 같은 문제)**:
  - 가이드 silhouette: **가이드 원본 사진 비율** (`sourceAspectRatio`) 기준 0-1 좌표
  - 카메라 프레임 사람 마스크: **카메라 프레임 비율** 기준 0-1 좌표
  - 두 비율이 다르면 IoU 계산 전에 같은 좌표계로 변환해야 함 — 가장 단순: 가이드를 카메라 비율로 letterbox 매핑한 후 비교 (Stage 4 렌더와 동일한 변환)
- 매칭 점수 계산 — 가장 단순하게 시작:
  - 변환된 가이드 마스크 vs 현재 사람 마스크의 **IoU (Intersection over Union)** 계산
  - 임계값(예: 0.7) 이상이면 "맞음"
- 임계값 통과 시 SwiftUI `@Published` 변수 토글:
  - `SilhouetteOverlay`의 색: 흰색 → 민트
  - `ShutterButton`의 `matched` 프롭: true (mint + glow)
  - Top chrome 중앙: 비율 칩 → "포즈 매칭" pill (mint 배경, mintDeep 텍스트, ✓ 아이콘)

---

### 6단계 — UI 마무리 (2~3일)

**대응 화면**: Screen 1 (카메라 화면)의 부가 UI 전체 마감.

**가이드라인 목록**:
- 촬영 버튼 상단에 가로 스크롤 (`ScrollView(.horizontal)` + 썸네일 원형)
- **빈 상태** — 가이드 0개일 때는 '+' 버튼만 (썸네일 영역 비움)
- **있는 상태** — 썸네일 목록 + 오른쪽 끝에 '+' 버튼
- 가이드 **탭** → 해당 가이드를 카메라 영역에 오버레이로 적용
- 가이드 **길게 누르기** → "가이드라인을 삭제할까요?" iOS 알럿 (`.alert`, 280pt 카드, 취소/삭제)
- 선택된 가이드 표시 (테두리 강조 등) — 한 번에 1개만 선택 가능

**'+' 버튼 동작** (Stage 2 진입 부분):
- 탭 → 모달 팝업 (`.confirmationDialog` 또는 `.sheet`)
  - "가이드 사진 찍기" → Screen 3
  - "가이드 사진 등록하기" → Screen 4

**Top chrome** (status bar 아래, 44pt 높이):
- **플래시 버튼** (우): on/off 토글. `AVCaptureDevice.torchMode` 또는 `AVCapturePhotoSettings.flashMode`.
- **화면 비율 토글** (중앙): 4:3 / 1:1 / 9:16 (세로 비율). 프리뷰의 cropping 또는 `AVCaptureSession.sessionPreset` 변경. (간단히는 SwiftUI에서 aspectRatio 마스킹만 해도 시각적으론 OK)

**Bottom controls** (84pt 검정 바, 셔터는 위에 floating):
- **갤러리 버튼** (좌): 디바이스 사진앱 열기 — 실제로는 사용자가 직전에 찍은 사진 확인용. iOS에는 "마지막 사진 썸네일"을 가져와 보여주는 패턴이 있음 (`PHAsset.fetchAssets` 최신 1장). 탭 시 시스템 사진앱 또는 in-app preview.
- **전면/후면 전환 버튼** (우): `AVCaptureDevice`를 다른 position으로 교체. `AVCaptureSession.beginConfiguration()` → 기존 input 제거 → 새 input 추가 → `commitConfiguration()`.
- 중앙은 비움 (셔터가 그 위에 floating).

**Screen 2 복귀 시 상태 처리** (Stage 3에서 만든 인터페이스 마무리):
- 완료 시 → 새 가이드를 목록에 추가 + 자동 선택 + 오버레이 적용된 상태로 Screen 1 복귀
- 취소 시 → 아무 가이드도 적용 안 된 상태로 Screen 1 복귀

---

## 추천 시작 방식

1단계까지만 먼저 끝낼 것. 카메라 프리뷰 + 셔터 + 저장이 굴러가는 순간 iOS 개발의 큰 그림이 잡힘. 이후 단계는 그 위에 얹는 거라 훨씬 수월.

전체 일정 가늠치:
- 풀타임 기준 **2~3주**
- 학습 곁들이면 **4~6주**
