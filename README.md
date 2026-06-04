# exelbid-ios-sdk-mediation

[ExelBid iOS SDK v3](../exelbid-ios-sdk-v3) 미디에이션용 서드파티 네트워크
어댑터 모음입니다. 각 어댑터는 별도의 SwiftPM 라이브러리로 제공되어,
호스트 앱은 실제로 사용하는 서드파티 광고 SDK만 링크하면 됩니다.

이 저장소에는 미디에이션 오케스트레이터·프로토콜·레지스트리가 **포함되어
있지 않습니다**. 이들은 `ExelBidSDK` 제품(메인 `exelbid-ios-sdk-v3`
저장소)에 번들로 들어 있어, 모든 SDK 사용자가 미디에이션 API를 자동으로
제공받습니다. 여기 있는 어댑터들은 그 계약과 각 네트워크의 iOS SDK 사이를
잇는 얇은 브리지일 뿐입니다.

## 어댑터 인벤토리

| 모듈 | 네트워크 | Banner | Interstitial | Native | Video | 기반 SDK | 최소 iOS | 배포 방식 |
|---|---|:-:|:-:|:-:|:-:|---|---|---|
| `ExelBidMediationAdMob` | Google AdMob | ✅ | ✅ | ✅ | ✅ (전면 비디오) | `GoogleMobileAds` 12.x | 14 | SwiftPM |
| `ExelBidMediationFAN` | Facebook Audience Network | ✅ | ✅ | ✅ | ✅ (전면 비디오) | `FBAudienceNetwork` 6.x+ | 14 | CocoaPods (호스트 링크) |
| `ExelBidMediationAdFit` | Kakao AdFit | ✅ | ✅ | ✅ | — | `AdFitSDK` 3.x | 13 | CocoaPods (호스트 링크) |
| `ExelBidMediationPangle` | ByteDance Pangle | 🟡 placeholder | TBD | TBD | TBD | `PAGAdSDK` 5.x | 12 | CocoaPods (호스트 링크) |
| `ExelBidMediationAppLovin` | AppLovin (SDK direct) | 🟡 placeholder | TBD | TBD | TBD | `AppLovinSDK` 12.x+ | 12 | CocoaPods (호스트 링크) |
| `ExelBidMediationDT` | Digital Turbine / Fyber | 🟡 placeholder | TBD | TBD | TBD | `IASDKCore` 8.x | 13 | CocoaPods (호스트 링크) |
| `ExelBidMediationTNK` | TNK Factory | 🟡 placeholder | TBD | TBD | TBD | `TnkAdSdk` 7.x | 11 | CocoaPods (호스트 링크) |
| `ExelBidMediationTargetPick` | MezzoMedia TargetPick | 🟡 placeholder | TBD | TBD | TBD | `ADMixerZ` | 11 | CocoaPods (호스트 링크) |

**Phase 4 placeholder 안내** (🟡):

Pangle / AppLovin / DT / TNK / TargetPick 모듈은 **등록 스캐폴드** 형태로
제공됩니다. 네트워크 ID가 `EBMediationRegistry`에 연결되고, 모듈의
`register(in:)`이 실행되며, 서버 워터폴이 올바르게 라우팅됩니다. 다만 각
네트워크 SDK로의 구체적인 브리지가 아직 구현되지 않아 어댑터의
`load(...)`는 현재 throw합니다. 해당 브리지가 작성되기 전까지
`isAvailable`은 `false`입니다. 오케스트레이터는 사용 불가 어댑터를 미등록
어댑터와 동일하게 취급하여(`EBWaterfallEvent.lost(.adapterNotRegistered)`)
다음으로 넘어갑니다.

placeholder를 채우는 방법:
1. 기반 서드파티 SDK를 링크합니다 (CocoaPods / binary target).
2. `<Network>BannerAdapter.swift`의 `#if canImport(<SDKModule>)` 블록을
   `AdMobBannerAdapter`를 모델로 한 실제 구현으로 교체합니다.
3. `isAvailable`을 `true`로 전환합니다.
4. `Tests/ExelBidMediationAdaptersTests/`에 실제 API 통합 테스트를
   추가합니다.

또는 호스트가 `EBBannerMediationAdapter`를 직접 구현한 자체 어댑터를
등록할 수도 있습니다 — `exelbid-ios-sdk-v3/docs/USAGE_GUIDE.md` §7 참고.

**TargetPick — 필수 설정**

TargetPick은 SDK 초기화 시 `(publisherId, mediaId)`가 필요합니다.
`ExelBidMediationKit.shared.register(modules:)` **이전에**
`TargetPickMediationModule.configure(...)`를 호출하세요:

```swift
TargetPickMediationModule.configure(
    publisherId: "<your publisher id>",
    mediaId:     "<your media id>"
)
ExelBidMediationKit.shared.register(modules: [
    TargetPickMediationModule.self,
    // …
])
```

**비디오 어댑터 관련 참고**:
- ExelBid 외 네트워크에서 미디에이션 **video 포맷은 전면(인터스티셜)
  비디오**를 의미합니다(보상형 아님). AdMob·FAN 비디오 어댑터는 각각
  `InterstitialAd` / `FBInterstitialAd`를 래핑하며, 비디오용 광고 유닛이
  영상 크리에이티브를 전면으로 자동 재생합니다. 분위(quartile) 진행률은
  근사 처리합니다(`onProgress(0)` 표시 시작, `onProgress(100)` 종료 시).
  보상형(rewarded) 광고가 필요한 호스트는 자체 어댑터를 등록하세요 —
  `exelbid-ios-sdk-v3/docs/USAGE_GUIDE.md` §7 참고.
- AdFit SDK는 전체화면 비디오 포맷을 제공하지 않으므로
  `AdFitMediationModule`은 비디오 어댑터를 의도적으로 등록하지 않습니다.
  서버 비디오 워터폴의 `"adfit"` 항목은
  `EBWaterfallEvent.lost(.adapterNotRegistered)`로 건너뛰어집니다.

**네이티브 어댑터 관련 참고**:
- AdMob과 FAN은 메인 이미지·동영상 에셋을 각 네트워크의 **미디어 뷰**로
  직접 렌더링합니다(이미지 URL로 표현되지 않음). 미디에이션 네이티브에서
  이 미디어(특히 동영상)를 표시하려면, 호스트의 `EBNativeAdRendering`
  뷰에 **빈 컨테이너 슬롯**을 노출하세요:

  ```swift
  func nativeMediaView() -> UIView? { mediaContainer }         // 메인 이미지/동영상 자리
  func nativeAdChoicesView() -> UIView? { adChoicesContainer } // FAN AdChoices 자리(선택)
  ```

  두 메서드 모두 선택(`@objc optional`)이며, 슬롯을 제공하지 않아도 정적
  이미지 네이티브는 정상 동작합니다(동영상은 미표시). 호스트 통합
  예시는 `exelbid-ios-sdk-v3/docs/README.md`의 네이티브 섹션을 참고하세요.
- AdFit은 이미지 URL 기반이라 별도 미디어 슬롯이 필요 없습니다.

ExelBid 자체 어댑터는 여기에 없습니다 — 서드파티 의존성이 전혀 없는
`ExelBidBuiltInMediationModule`로 메인 SDK에 함께 제공됩니다.

### FAN과 AdFit에 대한 참고

Facebook Audience Network와 Kakao AdFit은 SwiftPM 패키지를 **제공하지
않습니다**. 어댑터 Swift 파일은 `#if canImport(...)`로 감싸져 있어,
SwiftPM 전용 환경에서는 no-op placeholder(`isAvailable == false`)로
컴파일됩니다. 실제 어댑터를 활성화하려면 호스트 앱이 직접 서드파티 SDK를
CocoaPods, Carthage, 또는 수동 binary target으로 링크해야 합니다. 호스트
타깃에서 `FBAudienceNetwork` 또는 `AdFitSDK`가 링크 가능해지면, 다음
빌드부터 어댑터가 실제 구현을 자동으로 사용합니다.

### iOS 배포 타깃

`ExelBidSDK` 자체는 iOS 13+를 지원합니다. 각 어댑터는 (ExelBidSDK, 기반
네트워크 SDK) 중 **최댓값**을 상속합니다 — 어댑터별 최소값은 위 표에
정리되어 있습니다. iOS 14+ 어댑터(예: AdMob)를 iOS 13을 타깃하는 호스트에
링크하면 링크 타임에 실패하므로, 어댑터 추가 전에 호스트의 배포 타깃을
올려야 합니다.

## 호스트 앱에 추가하기

### Swift Package Manager

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/exelbid/exelbid-ios-sdk-v3.git",
             from: "3.0.0"),
    .package(url: "https://github.com/exelbid/exelbid-ios-sdk-mediation.git",
             from: "1.0.0"),
],
targets: [
    .target(
        dependencies: [
            .product(name: "ExelBidSDK", package: "exelbid-ios-sdk-v3"),
            .product(name: "ExelBidMediationAdMob", package: "exelbid-ios-sdk-mediation"),
            .product(name: "ExelBidMediationFAN", package: "exelbid-ios-sdk-mediation"),
            // …실제로 사용하는 것만
        ]
    )
]
```

SwiftPM에서는 각 어댑터가 별도 모듈이므로 사용하는 어댑터를 개별 import
합니다 (`import ExelBidMediationAdMob`).

### CocoaPods

```ruby
# Podfile
pod 'ExelBid_Mediation_Adapter/AdMob'
pod 'ExelBid_Mediation_Adapter/FAN'
# …실제로 사용하는 subspec만
```

CocoaPods에서는 모든 subspec이 `ExelBidMediationAdapter`라는 **하나의
모듈로** 컴파일됩니다(pod 배포명은 `ExelBid_Mediation_Adapter`이지만
`s.module_name`으로 import명을 분리). 따라서 어떤 subspec을 설치하든
`import ExelBidMediationAdapter` 하나만 추가하면 되고, 링크된 어댑터(위
예시에서는 AdMob/FAN)만 사용 가능합니다. 각 네트워크 SDK
자체(`Google-Mobile-Ads-SDK`, `FBAudienceNetwork`, `AdFitSDK`)는 subspec
의존성으로 함께 설치됩니다.

### 앱 시작 시 모듈 등록

```swift
// AppDelegate.swift
import ExelBidSDK
import ExelBidMediationAdMob   // SwiftPM: 어댑터별 import
import ExelBidMediationFAN
// CocoaPods로 설치한 경우: import ExelBidMediationAdapter 하나만

func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions …) -> Bool {
    ExelBidMediationKit.shared.register(modules: [
        ExelBidBuiltInMediationModule.self,
        AdMobMediationModule.self,
        FANMediationModule.self
    ])
    return true
}
```

> `ExelBidBuiltInMediationModule`을 포함하지 않으면 서버 워터폴 응답의
> "exelbid" 항목이 건너뛰어집니다. 일반적으로 항상 함께 등록하세요.

### 광고 호출

```swift
// 어디서든:
import ExelBidSDK

let banner = EBMediatedBannerAd(
    adUnitId: "YOUR_AD_UNIT_ID",
    size: CGSize(width: 320, height: 50)
)
banner.onLoad = { print("낙찰 네트워크: \(banner.winningNetwork ?? "?")") }
view.addSubview(banner)
banner.load()
```

## 로컬 빌드

이 저장소를 개발하는 동안 `Package.swift`는 `exelbid-ios-sdk-v3`를 상대
경로(`../exelbid-ios-sdk-v3`)로 소비합니다. 배포 릴리스에서는 이 경로가
버전이 지정된 URL로 교체됩니다.

```bash
DEST=$(xcrun simctl list devices available | grep -E "iPhone [0-9]+ \(" \
       | head -1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')

xcodebuild -scheme ExelBidMediationAdMob \
  -destination "platform=iOS Simulator,id=$DEST" \
  build
```

각 어댑터 타깃은 기반 서드파티 SDK가 SwiftPM 캐시에 있어야 합니다. 첫
빌드 시 이를 내려받고, 이후 빌드는 캐시를 재사용합니다.

## 새 네트워크 어댑터 추가하기

1. `Sources/ExelBidMediation<Network>/`를 생성합니다.
2. `ExelBidSDK`의 프로토콜을 채택하는 `<Network>BannerAdapter`(필요에
   따라 나머지도)를 구현합니다.
3. `EBMediationModule`을 구현하는 `<Network>MediationModule` enum을
   추가합니다.
4. 위 `Package.swift`에 product + target을 추가합니다.
5. 각 어댑터 파일 상단에 버전 호환성을 문서화합니다.

표준 예시는 `Sources/ExelBidMediationAdMob/AdMobBannerAdapter.swift`를
참고하세요.

> **전면/비디오 공유 패턴**: AdMob의 전면 슬롯은 디스플레이(배너/이미지)·
> 비디오 크리에이티브를 같은 `InterstitialAd` 객체로 재생합니다(SDK
> 레벨에서 "비디오만" 요청 불가 — 광고 유닛 설정이 결정). 그래서
> `AdMobInterstitialAdapter`와 `AdMobVideoAdapter`는 공유 드라이버
> `AdMobFullScreenAd`(load/present + delegate 브리징)를 함께 쓰고, 각
> 어댑터는 포맷별 콜백(`onClickFinish` / `onProgress`)만 연결합니다. 같은
> 풀스크린 SDK를 전면·비디오 두 포맷에 쓰는 네트워크라면 이 구조를
> 참고하세요.

## 버전 관리

어댑터는 기반 SDK의 메이저 버전을 따라갑니다. 네트워크가 breaking change를
배포하면:

1. `Package.swift`의 SwiftPM 의존성을 갱신합니다.
2. 어댑터를 새 API에 맞게 갱신합니다.
3. 각 어댑터 파일 상단의 "Compatible with:" 헤더를 갱신합니다.
4. 이 패키지의 마이너 버전을 올립니다.
</content>
</invoke>
