# Poby iOS 재구현 명세

이 문서는 현재 워크스페이스의 배포 산출물, 스토어 등록 정보, 스크린샷, AAB 리소스를 기준으로 iOS 앱을 동일한 UX로 재구현하기 위한 작업 명세다.

## 현재 확인 가능한 근거

- Android 원본 소스는 현재 루트에 없다. 확인 가능한 자료는 `배포v1.0.1/app-release.aab`, `배포v1/release/app-release.aab`, `배포v1/스토어 등록 정보.txt`, `screenshots/`, `reference-photos/`, `ad-assets/`다.
- AAB 기준 기술 스택은 AndroidX Camera, Jetpack Compose, Navigation Compose, DataStore Preferences, ML Kit selfie/subject segmentation, Firebase Crashlytics, 광고 ID 설정이다.
- 앱의 핵심 문구는 "좋아하는 구도를 저장해두고, 그 위에 맞춰 다시 찍어요. 같은 구도, 더 좋은 한 컷."이다.
- 핵심 기능은 사진에서 인물 가이드라인 자동 추출, 카메라 위 실시간 오버레이, 여러 가이드 저장 및 빠른 전환이다.

## 제품 개념

Poby는 사용자가 마음에 드는 사진을 고르면 사진 속 인물 형태를 자동으로 추출하고, 그 실루엣을 카메라 프리뷰 위에 띄워 같은 구도/포즈로 다시 촬영하게 해주는 포즈 가이드 카메라다.

주요 사용자는 친구/연인/여행 사진을 같은 구도로 재현하고 싶은 사람, 혼자 여행 중 원하는 구도를 맞추고 싶은 사람, 인스타그램 피드 톤과 구도를 맞추고 싶은 사람이다.

## iOS 권장 기술 스택

- 언어/UI: Swift, SwiftUI
- 카메라: AVFoundation
- 사진 선택: PhotosUI `PHPickerViewController` 또는 SwiftUI `PhotosPicker`
- 사진 저장/권한: Photos framework
- 인물/피사체 분리:
  - 1순위: Vision person segmentation / foreground instance mask 계열 API
  - 2순위: TensorFlow Lite로 Android 번들 내 selfie segmentation과 동등한 온디바이스 모델 사용
- 이미지 처리: Core Image, Core Graphics, Metal 선택 가능
- 로컬 저장: SwiftData 또는 Core Data, 단순 설정은 UserDefaults
- 분석/크래시: Amplitude, Firebase Crashlytics
- 광고/마케팅 전송이 필요하면 Meta SDK 및 App Tracking Transparency 검토 필요

## 정보 구조

### 1. 온보딩 화면

첫 실행 시 한 번 노출한다.

구성:
- 배경: 따뜻한 아이보리 계열
- 상단 작은 라벨: `WHY POBY`
- 메인 문구: `사진 찍을 때` / `구도 잡기 힘들지 않으셨나요?`
- 중앙 카드형 예시 이미지: 인물 사진 위에 민트 실루엣 라인, 상단 배지 `구도 매칭`
- 하단 강조 문구: `이제 poby와 함께 하세요`
- 보조 문구: `가이드라인 위에 따라 찍기만 하면` / `구도 걱정 없이 사진을 남길 수 있어요.`
- CTA: 민트색 큰 버튼 `시작하기  ->`

동작:
- `시작하기` 탭 시 온보딩 완료 플래그 저장 후 카메라 화면으로 이동한다.
- 카메라/사진 권한은 이 화면에서 미리 요청하지 않고, 실제 기능 진입 시 요청하는 편이 iOS UX에 맞다.

### 2. 카메라 메인 화면

앱의 기본 홈 화면이다.

상단 영역:
- 상태바 아래 아이보리 툴바
- 좌측 원형 버튼: 팔레트/가이드 색상 변경
- 중앙 캡슐 버튼: 기본은 `3:4`, 매칭 시 `✓ 포즈 매칭`
- 우측 원형 버튼: 플래시 토글

프리뷰 영역:
- 세로형 카메라 프리뷰가 화면 대부분을 차지한다.
- 선택된 가이드가 있으면 인물 윤곽선을 오버레이한다.
- 매칭 성공 상태에서는 윤곽선 색상이 민트로 표시되고 상단 중앙 배지가 `✓ 포즈 매칭`으로 바뀐다.
- 가이드가 없으면 중앙 안내 문구: `+ 버튼을 눌러` / `첫 가이드를 추가해보세요`

줌 컨트롤:
- 프리뷰 하단 위쪽에 원형 반투명 버튼 4개: `0.6x`, `1x`, `2x`, `3x`
- 선택값은 민트 텍스트로 표시한다.
- iOS 기기별 카메라 지원 배율에 따라 가능한 값만 활성화한다.

가이드 썸네일 레일:
- 프리뷰와 하단 컨트롤 사이에 가로 스크롤 목록
- 저장된 가이드 썸네일을 둥근 사각형으로 표시한다.
- 선택된 썸네일은 민트 테두리
- `+` 타일을 항상 표시해서 새 가이드 추가 진입점으로 사용한다.

하단 촬영 컨트롤:
- 중앙 대형 셔터 버튼: 검정 원 + 흰색 링
- 좌측 원형 버튼: 앨범/최근 사진 진입 또는 촬영 결과 갤러리
- 우측 원형 버튼: 전/후면 카메라 전환

### 3. 사진 선택 및 가이드 생성 플로우

진입:
- 카메라 화면의 `+` 가이드 버튼을 탭한다.
- Photos 권한이 없으면 iOS 권한 안내 후 시스템 피커를 띄운다.

처리:
- 사용자가 사진을 선택한다.
- 원본 이미지를 앱 내부 처리 크기로 리사이즈한다.
- Vision 또는 TFLite 모델로 인물/피사체 마스크를 생성한다.
- 마스크 경계를 추출해 투명 PNG 또는 벡터 Path 형태로 저장한다.
- 썸네일 이미지를 생성한다.
- 생성 완료 후 카메라 화면으로 돌아와 새 가이드를 선택 상태로 둔다.

실패 처리:
- 인물이 감지되지 않으면 "인물을 찾지 못했어요. 다른 사진을 선택해보세요."류의 안내를 띄운다.
- 사진 로딩/처리 중에는 모달 로딩 상태를 보여준다.
- 권한 거부 시 설정 앱 이동 CTA를 제공한다.

### 4. 촬영 플로우

동작:
- 셔터를 누르면 현재 카메라 프레임을 캡처한다.
- 저장 위치는 기기 사진 보관함이다.
- 가이드 오버레이는 최종 사진에 합성하지 않는 것이 기본 UX로 보인다. 최종 합성 여부는 별도 제품 결정이 필요하다.

촬영 후:
- 성공 피드백을 짧게 표시한다.
- 좌측 앨범 버튼 또는 최근 썸네일에서 결과 확인 가능하게 한다.

### 5. 가이드 관리

필수 기능:
- 여러 장의 가이드 저장
- 가이드 썸네일 빠른 전환
- 선택된 가이드 유지
- 앱 재실행 후에도 가이드 목록 유지

권장 추가 기능:
- 썸네일 롱프레스 또는 편집 모드로 삭제
- 가이드 이름 없이 썸네일 중심 관리
- 최대 저장 개수 제한은 초기에는 두지 않되, 저장 용량이 커지면 압축/캐시 정책 필요

## 디자인 시스템

### 색상

- Brand Mint: `#4FD3B6` 근사값
- Mint Dark Text: `#0A3A35` 근사값
- Background Ivory: `#F8F6F1` 또는 `#FAF8F3`
- Primary Text: `#111111`
- Secondary Text: `#9A9AA0`
- Control Fill: `#ECEBE6`
- Control Stroke: `#D3D0CA`
- Dark Overlay: `rgba(0, 0, 0, 0.55)`
- White Overlay Line: `#FFFFFF` with shadow/blur

### 타이포그래피

- 한국어 기본: Pretendard 계열이 Android 스크린샷과 가장 유사하다.
- iOS 시스템 구현 시 `SF Pro`/`SF Pro Rounded` + 한국어 시스템 폰트 사용 가능.
- 온보딩 타이틀: Bold/Heavy, 중앙 정렬
- 버튼/배지: Bold
- 보조 문구: Regular/Semibold, 회색

### 컴포넌트

- 원형 아이콘 버튼: 48-60pt, 아이보리/회색 배경, 얇은 회색 테두리
- 캡슐 버튼: 높이 38-44pt, 둥근 반경 19-22pt
- CTA 버튼: 높이 68-78pt, 좌우 24pt 마진, 반경 24pt 내외
- 썸네일: 64-76pt 정사각형, 반경 12-16pt, 선택 시 3-4pt 민트 테두리
- 셔터: 88-104pt, 검정 내부 원 + 흰 링 + 외곽 검정 링

## 데이터 모델

`Guide`
- `id: UUID`
- `createdAt: Date`
- `sourceImagePath: String`
- `thumbnailPath: String`
- `outlinePath: String`
- `maskPath: String?`
- `aspectRatio: Double`
- `dominantBounds: CGRect?`
- `outlineColorPreference: String?`

`AppSettings`
- `hasCompletedOnboarding: Bool`
- `selectedGuideId: UUID?`
- `selectedZoom: Double`
- `selectedAspectRatio: String`
- `guideColor: String`
- `flashMode: off/on/auto`
- `cameraPosition: back/front`

## 권한 및 개인정보

필수 권한:
- Camera: 촬영 및 실시간 가이드 매칭
- Photo Library Add/Read: 가이드 사진 선택, 촬영 결과 저장

iOS 문구 예시:
- `NSCameraUsageDescription`: `사진 촬영과 가이드 오버레이를 위해 카메라 접근이 필요합니다.`
- `NSPhotoLibraryUsageDescription`: `가이드로 사용할 사진을 선택하기 위해 사진 보관함 접근이 필요합니다.`
- `NSPhotoLibraryAddUsageDescription`: `촬영한 사진을 사진 보관함에 저장하기 위해 필요합니다.`

분석/광고:
- Android v1.0.1 설정에 광고 ID 수집 및 Meta 전송 추가 메모가 있다.
- iOS에서 Meta 광고/마케팅 SDK를 붙이면 ATT 팝업, App Store Privacy Nutrition Label, 추적 여부 정책을 함께 설계해야 한다.
- 광고 목적이 아직 확정되지 않았다면 iOS 1차 구현에서는 Crashlytics/Amplitude만 붙이고 Meta는 별도 브랜치로 분리하는 것을 권장한다.

## 알고리즘 구현 메모

가이드 생성:
1. 원본 이미지를 처리용 최대 변 1024-1536px로 축소한다.
2. 사람/피사체 마스크를 생성한다.
3. 마스크를 threshold 처리하고 작은 노이즈를 제거한다.
4. contour를 추출한다.
5. contour를 부드럽게 보정한다.
6. 표시용 라인은 3-6pt, 둥근 join/cap으로 렌더링한다.
7. 원본 이미지 좌표계와 카메라 프리뷰 좌표계 간 `aspectFill` 변환을 저장/계산한다.

포즈 매칭:
- 현재 Android 스크린샷에서는 정교한 점수 UI보다 "윤곽선이 맞으면 배지 색상 변경" 수준으로 보인다.
- iOS 1차 구현은 선택 가이드를 오버레이하고, 실시간 segmentation bounding box와 가이드 bounding box 간 IoU/중심점/스케일 차이가 임계값 이내일 때 `포즈 매칭` 상태로 처리한다.
- 고도화 시 사람 마스크 contour 또는 Vision human body pose points까지 비교한다.

## 화면별 체크리스트

- 온보딩 최초 실행/재실행 미노출
- 카메라 권한 허용/거부/설정 이동
- 사진 권한 허용/제한된 접근/거부
- 가이드 없는 카메라 상태
- 가이드 추가 처리 중/성공/실패
- 가이드 1개/여러 개 선택
- 줌 버튼 선택 및 실제 카메라 배율 변경
- 플래시 토글
- 전/후면 카메라 전환
- 사진 촬영 및 보관함 저장
- 앱 재시작 후 가이드 목록/선택값 복원
- 다크모드에서도 의도한 밝은 카메라 UI 유지 여부 결정

## App Store 준비물

- 앱 이름 후보: `포비 - 인생샷 가이드 카메라`, `Poby - Pose Guide Camera`
- 카테고리: 사진 및 비디오
- 키워드: 카메라, 사진, 셀카, 인물, 구도, 포즈, 가이드라인
- 개인정보 처리방침 URL 필요
- 앱 아이콘: 현재 `배포v1/icon.png`의 민트 배경 + 흰 조준선 형태를 iOS 규격으로 재작업
- 스크린샷: Android용 `배포v1/screenshot/ko`, `배포v1/screenshot/en` 콘셉트를 iOS 디바이스 프레임으로 재제작

## 구현 우선순위

1. SwiftUI 프로젝트 생성, 디자인 토큰/공통 버튼/카메라 화면 골격 구현
2. AVFoundation 카메라 프리뷰, 셔터, 전/후면 전환, 줌 구현
3. 온보딩 및 로컬 설정 저장
4. 사진 선택 플로우 구현
5. 인물 마스크/윤곽선 추출 구현
6. 가이드 저장/썸네일 레일/선택 복원 구현
7. 가이드 오버레이 좌표 변환 정밀 보정
8. 포즈 매칭 배지 구현
9. 촬영 결과 저장 및 권한/오류 처리
10. Amplitude/Firebase Crashlytics, 필요 시 Meta/ATT 연결
11. iOS 스토어 자산, 개인정보 라벨, QA

## 미확정 사항

- 최종 촬영 사진에 가이드 라인을 합성할지 여부
- 가이드 삭제/재정렬 UX
- 포즈 매칭의 정확도 기준
- Meta 광고 SDK를 iOS 초기 버전에 포함할지 여부
- iOS 타깃 버전
- Vision만으로 충분한지, TFLite 모델을 포함할지 여부
