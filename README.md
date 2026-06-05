# ExelBid_iOS_Mediation_Adapter

ExelBid iOS SDK v3 미디에이션용 서드파티 네트워크 어댑터 모음입니다. 각
어댑터는 별도의 SwiftPM 라이브러리로 제공되어, 호스트 앱은 실제로 사용하는
서드파티 광고 SDK만 링크하면 됩니다.

미디에이션 오케스트레이터·프로토콜·레지스트리는 `ExelBidSDK`에 번들로 들어
있어, 모든 SDK 사용자가 미디에이션 API를 자동으로 제공받습니다. 여기 있는
어댑터들은 그 계약과 각 네트워크의 iOS SDK 사이를 잇는 얇은 브리지입니다.

> 📖 **자세한 내용은 [ExelBid iOS SDK](https://github.com/onnuridmc/ExelBid_iOS_Swift)
> 의 미디에이션 항목을 참고하세요.**

## 어댑터 인벤토리

| 모듈 | 네트워크 | Banner | Interstitial | Native | Video | 기반 SDK | 최소 iOS | 배포 방식 |
|---|---|:-:|:-:|:-:|:-:|---|---|---|
| `ExelBidMediationAdMob` | Google AdMob | ✅ | ✅ | ✅ | ✅ (전면 비디오) | `GoogleMobileAds` 12.x | 14 | SwiftPM · CocoaPods |
| `ExelBidMediationFAN` | Facebook Audience Network | ✅ | ✅ | ✅ | ✅ (전면 비디오) | `FBAudienceNetwork` 6.x+ | 14 | CocoaPods (호스트 링크) |
| `ExelBidMediationAdFit` | Kakao AdFit | ✅ | — | ✅ | — | `AdFitSDK` 3.x | 13 | SwiftPM 전용 |
| `ExelBidMediationPangle` | ByteDance Pangle | 🟡 예정 | TBD | TBD | TBD | `PAGAdSDK` 5.x | 12 | 미배포 |
| `ExelBidMediationAppLovin` | AppLovin (SDK direct) | 🟡 예정 | TBD | TBD | TBD | `AppLovinSDK` 12.x+ | 12 | 미배포 |
| `ExelBidMediationDT` | Digital Turbine / Fyber | 🟡 예정 | TBD | TBD | TBD | `IASDKCore` 8.x | 13 | 미배포 |
| `ExelBidMediationTNK` | TNK Factory | 🟡 예정 | TBD | TBD | TBD | `TnkAdSdk` 7.x | 11 | 미배포 |
| `ExelBidMediationTargetPick` | MezzoMedia TargetPick | 🟡 예정 | TBD | TBD | TBD | `ADMixerZ` | 11 | 미배포 |

**지원 예정 네트워크** (🟡):

Pangle / AppLovin / DT / TNK / TargetPick 어댑터는 아직 제공되지 않습니다.
서버 워터폴에 해당 네트워크가 포함되어 있어도 현재는 사용 불가 어댑터로
처리되어(`EBWaterfallEvent.lost(.adapterNotRegistered)`) 다음 네트워크로
넘어갑니다.

필요한 네트워크가 아직 목록에 없다면, 호스트가 `EBBannerMediationAdapter`
등을 직접 구현한 자체 어댑터를 등록할 수도 있습니다(ExelBid iOS SDK 문서
참고).

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
  보상형(rewarded) 광고가 필요한 호스트는 자체 어댑터를 등록하세요(ExelBid
  iOS SDK 문서 참고).
- AdFit SDK는 배너·네이티브 포맷만 제공합니다(전면 인터스티셜·전체화면
  비디오 API가 없음). 따라서 `AdFitMediationModule`은 배너·네이티브만
  등록하며, 서버 워터폴의 인터스티셜/비디오 `"adfit"` 항목은
  `EBWaterfallEvent.lost(.adapterNotRegistered)`로 건너뛰어집니다.

**네이티브 어댑터 관련 참고**:
- AdMob·FAN·AdFit 모두 메인 이미지·동영상 에셋을 각 네트워크의 **미디어
  뷰**로 직접 렌더링합니다(이미지 URL로 표현되지 않음). 미디에이션
  네이티브에서 이 미디어(특히 동영상)를 표시하려면, 호스트의
  `EBNativeAdRendering` 뷰에 **빈 컨테이너 슬롯**을 노출하세요:

  ```swift
  func nativeMediaView() -> UIView? { mediaContainer }         // 메인 이미지/동영상 자리
  func nativeIconImageView() -> UIImageView? { iconImageView } // 아이콘 자리
  func nativeAdChoicesView() -> UIView? { adChoicesContainer } // FAN AdChoices 자리(선택)
  ```

  모두 선택(`@objc optional`)이며, 슬롯을 제공하지 않아도 텍스트 자산은
  정상 동작합니다(미디어는 미표시). 호스트 통합 예시는 ExelBid iOS SDK
  문서의 네이티브 섹션을 참고하세요.
- AdFit 네이티브는 미디어/아이콘을 SDK 뷰(`AdFitMediaView` 등)로
  렌더링하므로 이미지 URL을 제공하지 않습니다. 위 슬롯을 노출하면
  어댑터가 해당 위치에 AdFit 미디어 뷰를 자동으로 배치합니다.

ExelBid 자체 어댑터는 여기에 없습니다 — 서드파티 의존성이 전혀 없는
`ExelBidBuiltInMediationModule`로 메인 SDK에 함께 제공됩니다.

### FAN·AdFit 통합 방식

Kakao AdFit은 공식 SwiftPM 패키지([`adfit-spm`](https://github.com/adfit/adfit-spm),
binary xcframework)를 제공하므로 AdFit 어댑터는 SwiftPM에서 별도 설정 없이
바로 동작합니다.

반면 Facebook Audience Network는 SwiftPM 패키지를 **제공하지 않습니다**.
FAN 어댑터 Swift 파일은 `#if canImport(FBAudienceNetwork)`로 감싸져 있어,
`FBAudienceNetwork`가 링크되지 않은 환경에서는 no-op
placeholder(`isAvailable == false`)로 컴파일됩니다. FAN 어댑터를 활성화하려면
호스트 앱이 직접 `FBAudienceNetwork`를 CocoaPods, Carthage, 또는 수동 binary
target으로 링크해야 하며, 링크 가능해지면 다음 빌드부터 어댑터가 실제 구현을
자동으로 사용합니다.

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
    .package(url: "https://github.com/onnuridmc/ExelBid_iOS_Swift.git",
             from: "3.0.0"),
    .package(url: "https://github.com/onnuridmc/ExelBid_iOS_Mediation_Adapter.git",
             from: "1.0.0"),
],
targets: [
    .target(
        dependencies: [
            .product(name: "ExelBidSDK", package: "ExelBid_iOS_Swift"),
            .product(name: "ExelBidMediationAdMob", package: "ExelBid_iOS_Mediation_Adapter"),
            .product(name: "ExelBidMediationFAN", package: "ExelBid_iOS_Mediation_Adapter"),
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
자체(`Google-Mobile-Ads-SDK`, `FBAudienceNetwork`)는 subspec 의존성으로
함께 설치됩니다.

> **AdFit은 CocoaPods로 제공되지 않습니다.** Kakao가 AdFit SDK의 CocoaPods
> 배포를 중단하여 의존 가능한 `AdFitSDK` pod이 없습니다. AdFit 어댑터는
> **SwiftPM 전용**이며, SwiftPM으로 통합하면 별도 설정 없이 동작합니다.

### AdFit 수동 통합 (SwiftPM을 쓸 수 없는 경우)

CocoaPods 등 SwiftPM이 아닌 환경에서 AdFit을 써야 한다면, AdFit SDK
바이너리와 어댑터 소스를 수동으로 추가합니다.

1. **AdFit SDK 다운로드** — [`adfit-spm`](https://github.com/adfit/adfit-spm)
   저장소에서 원하는 버전 태그(예: `3.21.24`)의 `AdFitSDK.xcframework`
   (`Frameworks/AdFitSDK.xcframework`) 또는 루트의 `AdFitSDK.zip`을
   내려받습니다.

   ```bash
   # 예: 특정 태그의 xcframework만 받기
   git clone --depth 1 --branch 3.21.24 https://github.com/adfit/adfit-spm
   # adfit-spm/Frameworks/AdFitSDK.xcframework 사용
   ```

2. **xcframework 임베드** — 받은 `AdFitSDK.xcframework`를 Xcode 타깃의
   *Frameworks, Libraries, and Embedded Content*에 추가하고 **Embed & Sign**
   으로 설정합니다.

3. **어댑터 소스 추가** — 이 저장소의
   `Sources/ExelBidMediationAdFit/` 안 `.swift` 파일들을 프로젝트에
   포함합니다. (CocoaPods subspec이 없으므로 직접 추가)

4. 위 과정으로 `AdFitSDK`가 링크되면 어댑터의 `#if canImport(AdFitSDK)`
   블록이 활성화되어 `AdFitMediationModule`이 정상 동작합니다.

> 가능하면 1~3단계를 자동으로 처리하는 **SwiftPM 통합을 권장**합니다.
> 수동 통합은 AdFit SDK 버전 업데이트도 직접 관리해야 합니다.

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
