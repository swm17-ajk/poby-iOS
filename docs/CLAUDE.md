# iOS Architecture Rules

## 목적

이 문서는 SwiftUI 기반 iOS 앱을 개발할 때 따를 공통 아키텍처 원칙을 정의한다.

기본 구조는 Feature-first MVVM + layered vertical slice다. 코드는 기능 단위로 먼저 모으고, 각 기능 안에서 `Presentation`, `Domain`, `Data`를 필요에 따라 나눈다. 여러 기능에서 실제로 공유되는 코드만 `Core`로 승격한다.

핵심 원칙:

- 기본 위치는 `Features/<Feature>`다.
- 두 Feature 이상에서 공유될 때만 `Core`로 올린다.
- `Presentation`은 UI와 화면 상태를 담당한다.
- `Domain`은 앱 규칙과 계약을 담당한다.
- `Data`는 외부 구현과 저장소 구현을 담당한다.
- `App`은 라우팅과 의존성 조립을 담당한다.

## 권장 전체 구조

```txt
App/
  MyApp.swift
  AppRootView.swift
  AppRoute.swift
  AppDIContainer.swift

Core/
  Presentation/
    Components/
    DesignSystem/
    Extensions/
    Utilities/

  Domain/
    Entities/
    UseCases/
    Repositories/
    Services/

  Data/
    Network/
    Persistence/
    DTO/
    Mappers/
    Repositories/
    Services/

Features/
  FeatureName/
    Presentation/
      View/
        FeatureNameView.swift
      ViewModel/
        FeatureNameViewModel.swift
      Model/
        FeatureNameViewState.swift
      Components/
        FeatureOnlyComponent.swift

    Domain/
      Entities/
      UseCases/
      Repositories/
      Services/

    Data/
      DTO/
      Mappers/
      Repositories/
      Services/

Resources/
  Assets.xcassets
  Localizable.xcstrings

Tests/
  UnitTests/
  UITests/
```

소규모 MVP에서는 비어 있는 폴더를 미리 만들지 않는다. 해당 Feature에 전용 `Domain`이나 `Data`가 없으면 `Presentation`만 있어도 된다.

## 최상위 책임

### App

앱의 조립 계층이다.

- 앱 진입점
- 전역 route
- tab/full screen/modal flow
- DI container
- Feature 간 navigation 연결
- 실제 repository/service/usecase 구현체 조립

`App`은 여러 계층을 알고 조립할 수 있다. 단, 비즈니스 로직이나 화면 세부 UI를 직접 구현하지 않는다.

### Core

여러 Feature에서 공유되는 코드만 둔다.

`Core`는 기본 저장소가 아니다. 처음부터 모든 모델, UseCase, Repository를 `Core`에 넣지 않는다. 한 Feature에서만 쓰는 코드는 Feature 내부에 둔다.

Core로 승격하는 기준:

- 두 Feature 이상에서 같은 Entity를 쓴다.
- 두 Feature 이상에서 같은 UseCase를 쓴다.
- 두 Feature 이상에서 같은 Repository protocol을 쓴다.
- 두 Feature 이상에서 같은 UI Component를 쓴다.
- API client, database, keychain, platform service wrapper처럼 앱 전체 인프라다.

### Features

각 기능의 vertical slice다.

Feature는 화면, 화면 상태, 기능 전용 UseCase, 기능 전용 Data 구현을 함께 소유할 수 있다.

기본 원칙:

- 기능 전용 코드는 Feature 안에 둔다.
- 다른 Feature가 직접 참조하지 않는다.
- 공유가 필요해지면 `Core`로 올린다.
- Feature 내부에서도 `Presentation -> Domain -> Data`의 방향을 지킨다.

## Feature 내부 구조

Feature 내부는 필요할 때 아래처럼 구성한다.

```txt
Features/FeatureName/
  Presentation/
    View/
      FeatureNameView.swift
    ViewModel/
      FeatureNameViewModel.swift
    Model/
      FeatureNameViewState.swift
    Components/
      FeatureSummaryView.swift
      FeatureActionBar.swift

  Domain/
    Entities/
      FeatureSessionState.swift
    UseCases/
      StartFeatureUseCase.swift
      ValidateFeatureInputUseCase.swift
      SubmitFeatureUseCase.swift
    Repositories/
      FeatureRepositoryProtocol.swift

  Data/
    DTO/
      FeatureSessionDTO.swift
    Mappers/
      FeatureSessionMapper.swift
    Repositories/
      FeatureRepository.swift
```

규칙:

- `Presentation`은 MVVM을 따른다.
- `Domain`은 기능 전용 규칙과 계약을 둔다.
- `Data`는 기능 전용 외부 구현을 둔다.
- `Domain`이나 `Data`가 필요 없으면 만들지 않는다.
- Feature 내부 코드는 같은 Feature의 하위 계층을 사용할 수 있다.
- 다른 Feature의 내부 파일은 직접 import하지 않는다.

## 의존 방향

권장 의존 방향:

```txt
App -> Core
App -> Features

Features/<Feature>/Presentation -> Features/<Feature>/Domain
Features/<Feature>/Presentation -> Core/Presentation
Features/<Feature>/Presentation -> Core/Domain

Features/<Feature>/Data -> Features/<Feature>/Domain
Features/<Feature>/Data -> Core/Domain
Features/<Feature>/Data -> Core/Data

Core/Presentation -> Core/Domain
Core/Data -> Core/Domain

Domain -> Foundation
```

금지:

- `Domain -> Presentation`
- `Domain -> Data`
- `Core/Domain -> Features`
- `Core/Data -> Features`
- `Core/Presentation -> Features`
- `Features/FeatureA -> Features/FeatureB`
- `View -> concrete Data implementation`

## Core와 Feature의 경계 기준

가장 중요한 판단 기준은 이 문장이다.

```txt
기본 위치는 Feature, 공유가 증명되면 Core.
```

### Entity

Feature 안에 둔다:

- 한 Feature 내부 규칙에만 쓰이는 상태
- 특정 화면/기능의 계산에만 필요한 값

Core로 올린다:

- 여러 Feature에서 같은 의미로 쓰는 도메인 개념
- 앱 전체 정책에 영향을 주는 모델

예시:

```txt
Features/FeatureName/Domain/Entities/FeatureSessionState.swift
Core/Domain/Entities/SharedEntity.swift
```

### UseCase

Feature 안에 둔다:

- 한 Feature에서만 실행하는 사용자 행동
- 특정 Feature 전용 흐름

Core로 올린다:

- 여러 Feature에서 호출하는 앱 공통 행동
- 여러 Feature에 같은 결과를 제공하는 조회/계산

예시:

```txt
Features/FeatureName/Domain/UseCases/SubmitFeatureUseCase.swift
Core/Domain/UseCases/FetchSharedEntityUseCase.swift
```

### Repository Protocol

Feature 안에 둔다:

- 한 Feature에서만 필요한 저장소 계약
- 기능 전용 임시 저장/조회 계약

Core로 올린다:

- 여러 Feature에서 같은 데이터 소스를 사용한다.
- 앱의 핵심 도메인 데이터에 접근한다.

예시:

```txt
Features/FeatureName/Domain/Repositories/FeatureRepositoryProtocol.swift
Core/Domain/Repositories/SharedEntityRepositoryProtocol.swift
```

### Data 구현

Feature 안에 둔다:

- 한 Feature에서만 쓰는 DTO
- 한 Feature 전용 mapper
- 한 Feature 전용 repository 구현

Core로 올린다:

- 공통 API client
- 공통 DB/Keychain/UserDefaults wrapper
- 여러 Feature가 공유하는 repository 구현
- 공통 service 구현

예시:

```txt
Features/FeatureName/Data/Mappers/FeatureResultMapper.swift
Core/Data/Network/APIClient.swift
Core/Data/Persistence/LocalDatabase.swift
```

### Presentation Component

Feature 안에 둔다:

- 한 화면 또는 한 Feature에서만 쓰는 UI

Core로 올린다:

- 두 Feature 이상에서 쓰는 UI
- 디자인 시스템 일부로 볼 수 있는 UI
- 앱 셸, 공통 헤더, 공통 바텀바, 공통 버튼

예시:

```txt
Features/FeatureName/Presentation/Components/FeatureHeader.swift
Core/Presentation/Components/PrimaryButton.swift
```

## Presentation 규칙

Presentation은 SwiftUI MVVM을 따른다.

```txt
Presentation/
  View/
  ViewModel/
  Model/
  Components/
```

### View

View의 책임:

- 화면 조립
- ViewModel state 표시
- 사용자 이벤트 전달
- navigation intent 외부 전달
- Preview 제공

View가 하지 않는 일:

- 네트워크 호출
- DB/UserDefaults/Keychain 직접 접근
- 시스템 권한, 센서, 플랫폼 서비스 직접 제어
- 비즈니스 규칙 계산
- concrete repository 생성
- 다른 Feature의 ViewModel 사용

### ViewModel

ViewModel의 책임:

- 화면 상태 보관
- 사용자 액션 처리
- UseCase 또는 Repository protocol 호출
- 로딩/에러/빈 상태 관리

규칙:

- `ObservableObject`를 사용한다.
- state는 `@Published private(set)`을 기본으로 한다.
- 화면 상태 모델은 `Presentation/Model`에 둔다.
- 의존성은 생성자 주입을 기본으로 한다.
- ViewModel은 SwiftUI View를 만들지 않는다.
- ViewModel은 색상, 폰트, spacing 같은 디자인 토큰을 소유하지 않는다.
- async state 변경은 MainActor 경계를 지킨다.

권장 예시:

```swift
@MainActor
final class FeatureViewModel: ObservableObject {
    @Published private(set) var state: FeatureViewState

    private let fetchUseCase: FetchSomethingUseCase

    init(
        state: FeatureViewState = .initial,
        fetchUseCase: FetchSomethingUseCase
    ) {
        self.state = state
        self.fetchUseCase = fetchUseCase
    }

    func appeared() async {
        state = .loading
        do {
            state = .loaded(try await fetchUseCase.execute())
        } catch {
            state = .failed(error)
        }
    }
}
```

### Component

Component 규칙:

- Feature 전용 Component는 `Features/<Feature>/Presentation/Components`에 둔다.
- 공통 Component는 `Core/Presentation/Components`에 둔다.
- Component는 ViewModel을 소유하지 않는다.
- 필요한 값과 action closure를 명시적으로 받는다.
- Component 이름은 역할이 드러나게 짓는다.

권장 예시:

```swift
struct MetricCard: View {
    let title: String
    let value: String
    let iconName: String
    let onTap: () -> Void
}
```

## Domain 규칙

Domain은 앱의 규칙과 계약을 담당한다.

Domain에 둘 수 있는 것:

- Entity
- Value Object
- UseCase
- Repository protocol
- Service protocol
- Policy
- domain error

Domain이 몰라야 하는 것:

- SwiftUI
- UIKit
- API DTO
- database entity
- UserDefaults key
- platform framework concrete type
- concrete repository implementation

Domain은 기본적으로 `Foundation`만 의존한다.

## Data 규칙

Data는 외부 세계와 직접 연결되는 구현 계층이다.

Data에 둘 수 있는 것:

- API client
- DTO
- Mapper
- database entity
- repository implementation
- service implementation
- cache
- local storage wrapper

규칙:

- Data는 Domain protocol을 구현한다.
- Data 모델을 Presentation으로 직접 넘기지 않는다.
- DTO와 Entity는 Mapper를 통해 Domain 모델로 변환한다.
- ViewModel은 Data 구현체를 직접 생성하지 않는다.

## Core/Presentation DesignSystem 규칙

디자인 값은 `Core/Presentation/DesignSystem`에 모은다.

권장 파일:

```txt
Core/Presentation/DesignSystem/
  AppColors.swift
  AppTypography.swift
  AppSpacing.swift
  AppRadius.swift
  AppShadow.swift
  AppMetrics.swift
```

규칙:

- 색상은 `AppColors`
- 폰트는 `AppTypography`
- spacing은 `AppSpacing`
- radius는 `AppRadius`
- shadow는 `AppShadow`
- 화면/컴포넌트 크기는 `AppMetrics`
- 같은 숫자가 두 번 이상 반복되면 token으로 올린다.
- safe area, common screen chrome, screen scale 계산은 여러 화면에 중복 구현하지 않는다.

## Navigation 규칙

- App 계층이 전역 navigation을 소유한다.
- Feature는 navigation intent만 외부로 전달한다.
- 깊은 Component가 직접 route를 변경하지 않는다.
- tab flow, full screen flow, modal flow를 명확히 구분한다.
- 화면 이동에 필요한 값은 typed model로 넘긴다.

권장 예시:

```swift
FeatureView(
    onDone: { route = .home },
    onDetailTapped: { item in route = .detail(item.id) }
)
```

## Dependency Injection 규칙

- App 계층에서 실제 구현체를 조립한다.
- ViewModel은 필요한 UseCase 또는 Repository protocol을 생성자에서 받는다.
- UseCase는 필요한 Repository protocol 또는 Service protocol을 생성자에서 받는다.
- Preview와 Test에서는 mock/fake 구현체를 주입한다.
- View 내부에서 concrete Data 구현체를 만들지 않는다.
- 전역 singleton은 불가피한 시스템 wrapper에만 제한적으로 사용한다.

## Mock과 Preview 규칙

- 주요 View는 Preview를 가진다.
- Preview는 기본, 빈 상태, 로딩, 에러, 긴 텍스트 상태를 확인할 수 있어야 한다.
- Feature 전용 mock은 해당 Feature 내부에 둔다.
- 여러 Feature에서 쓰는 mock helper만 Core 또는 Test support로 올린다.
- mock 데이터가 production flow에 섞이지 않게 한다.

## 테스트 원칙

- ViewModel 상태 전이는 Unit Test로 검증한다.
- UseCase 비즈니스 규칙은 Unit Test로 검증한다.
- Mapper는 DTO와 Domain 변환을 검증한다.
- Repository 구현은 fake API/local store로 검증한다.
- 핵심 사용자 흐름은 UI Test로 검증한다.
- 테스트하기 어렵다면 의존 방향이나 책임 분리를 먼저 의심한다.

## 새 기능 추가 절차

1. `Features/<FeatureName>` 폴더를 만든다.
2. 먼저 `Presentation`을 만든다.
3. 필요한 경우에만 Feature 내부 `Domain`을 만든다.
4. 필요한 경우에만 Feature 내부 `Data`를 만든다.
5. 두 Feature 이상에서 공유되는 순간 `Core`로 승격한다.
6. App 계층에서 route와 dependency를 연결한다.
7. 공통 UI와 디자인 값은 `Core/Presentation`으로 올린다.
8. Preview와 테스트를 추가한다.
9. 빌드와 주요 화면 동작을 확인한다.

## 금지 패턴

- 처음부터 모든 코드를 Core에 넣는 것
- Feature끼리 서로 직접 참조하는 것
- View 안에 API 호출을 직접 넣는 것
- View 안에 저장소 구현체를 만드는 것
- Component가 ViewModel을 직접 생성하는 것
- Domain에 SwiftUI 타입을 넣는 것
- Presentation에서 DTO나 database entity를 직접 사용하는 것
- Data 모델을 그대로 View에 넘기는 것
- 디자인 숫자와 색상을 화면마다 하드코딩하는 것
- safe area, common screen chrome 계산을 여러 화면에 중복 구현하는 것
- mock 데이터를 production flow에 그대로 남기는 것

## 판단 체크리스트

새 파일 위치가 애매하면 아래 순서로 판단한다.

1. 한 Feature에서만 쓰는가?
   - 그렇다면 `Features/<Feature>` 안에 둔다.
2. 두 Feature 이상에서 실제로 쓰는가?
   - 그렇다면 `Core`로 올린다.
3. UI인가?
   - `Presentation`
4. 앱 규칙, 계약, Entity인가?
   - `Domain`
5. API, DB, DTO, Mapper, concrete 구현인가?
   - `Data`
6. navigation이나 dependency 조립인가?
   - `App`

이 기준으로도 애매하면 일단 Feature 내부에 둔다. 공유가 증명되기 전까지 Core로 올리지 않는다.

