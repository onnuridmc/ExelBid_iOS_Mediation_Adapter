# ExelBid_iOS_Mediation_Adapter

ExelBid iOS SDK 미디에이션용 서드파티 네트워크 어댑터 모음입니다. 각
어댑터는 별도의 SwiftPM 라이브러리로 제공되어, 호스트 앱은 실제로 사용하는
서드파티 광고 SDK만 링크하면 됩니다.

미디에이션 기능 자체는 `ExelBidSDK`에 포함되어 있어, SDK를 설치하면 미디에이션
API를 바로 사용할 수 있습니다. 여기 있는 어댑터들은 그 미디에이션과 각
네트워크의 iOS SDK 사이를 잇는 브리지입니다.

이 저장소(README)는 **어댑터 인벤토리와 설치 방법**을 다룹니다. 미디에이션
광고 호출·네이티브 렌더링·옵션 설정·자체 어댑터 작성 등 **자세한 사용법**은
아래 가이드를 참고하세요.

> 📖 **미디에이션 어댑터 사용자 가이드** —
> [`ExelBid_iOS_Swift` › docs/MEDIATION_ADAPTER_GUIDE.md](https://github.com/onnuridmc/ExelBid_iOS_Swift/blob/main/MEDIATION_ADAPTER_GUIDE.md)
>
> 호스트 통합(배너/전면/네이티브/비디오 호출, `EBNativeAdRendering` 슬롯
> 구성, `EBAdOptions` 적용 등)은 [ExelBid iOS SDK 문서](https://github.com/onnuridmc/ExelBid_iOS_Swift)
> 의 미디에이션 항목에 정리되어 있습니다.

## 어댑터 인벤토리

| 모듈 | 네트워크 | Banner | Interstitial | Native | Video | 기반 SDK | 최소 iOS | 배포 방식 |
|---|---|:-:|:-:|:-:|:-:|---|---|---|
| `ExelBidMediationAdMob` | Google AdMob | ✅ | ✅ | ✅ | ✅ (전면 비디오) | `GoogleMobileAds` 12.x | 14 | SwiftPM · CocoaPods |
| `ExelBidMediationFAN` | Facebook Audience Network | ✅ | ✅ | ✅ | ✅ (전면 비디오) | `FBAudienceNetwork` 6.x+ | 14 | CocoaPods (호스트 링크) |
| `ExelBidMediationAdFit` | Kakao AdFit | ✅ | — | ✅ | — | `AdFitSDK` 3.x | 13 | SwiftPM 전용 |

그 외 네트워크는 순차적으로 지원될 예정입니다. 서버 워터폴에 아직 지원되지
않는 네트워크가 포함되어 있으면 자동으로 건너뛰고 다음 네트워크로
넘어갑니다. 목록에 없는 네트워크가 필요하면 호스트가 어댑터를 직접 구현해
등록할 수도 있습니다(작성 방법은 위 어댑터 가이드 참고).

ExelBid 자체 어댑터는 이 저장소에 없습니다 — 서드파티 의존성 없이 메인 SDK에
기본 포함됩니다.

### 네트워크별 참고 (요약)

- **비디오** — ExelBid 외 네트워크의 미디에이션 video 포맷은 **전면(인터스티셜)
  비디오**를 의미합니다(보상형 아님). 재생 진행률은 시작·종료 두 시점만
  근사 보고됩니다.
- **AdFit** — 배너·네이티브만 제공합니다(전면/전체화면 비디오 API 없음).
  워터폴의 인터스티셜/비디오 AdFit 항목은 자동으로 건너뛰어집니다.
- **네이티브** — AdMob/FAN/AdFit은 메인 이미지·동영상을 각 네트워크의 미디어
  뷰로 직접 렌더링합니다. 호스트 `EBNativeAdRendering` 뷰에 미디어 슬롯을
  노출하는 방법은 어댑터 가이드의 네이티브 섹션을 참고하세요.

> 위 동작과 슬롯 구성, 옵션 전달 등 자세한 내용은
> [미디에이션 어댑터 사용자 가이드](https://github.com/onnuridmc/ExelBid_iOS_Swift/blob/main/MEDIATION_ADAPTER_GUIDE.md)
> 에 정리되어 있습니다.

## 설치

> **버전 호환**: 어댑터는 같은 시점의 `ExelBidSDK`와 함께 사용해야 합니다.
> `ExelBidSDK` 3.0.3 이상은 어댑터 **1.1.4 이상**이 필요합니다.

### Swift Package Manager

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/onnuridmc/ExelBid_iOS_Swift.git",
             from: "3.0.3"),
    .package(url: "https://github.com/onnuridmc/ExelBid_iOS_Mediation_Adapter.git",
             from: "1.1.4"),
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
pod 'ExelBid_Mediation_Adapter/AdMob', '~> 1.1.4'
pod 'ExelBid_Mediation_Adapter/FAN',   '~> 1.1.4'
# …실제로 사용하는 subspec만
```

CocoaPods에서는 어떤 subspec을 설치하든 `import ExelBidMediationAdapter`
하나만 추가하면 되고, 링크된 어댑터(위 예시에서는 AdMob/FAN)만 사용
가능합니다. 각 네트워크 SDK 자체(`Google-Mobile-Ads-SDK`,
`FBAudienceNetwork`)는 subspec 의존성으로 함께 설치됩니다.

> **AdFit은 CocoaPods로 제공되지 않습니다.** 의존 가능한 `AdFitSDK` pod이
> 없어, AdFit 어댑터는 **SwiftPM 전용**입니다. SwiftPM으로 통합하면 별도
> 설정 없이 동작합니다.

### FAN 통합 방식

Facebook Audience Network는 SwiftPM 패키지를 제공하지 않습니다. FAN 어댑터를
사용하려면 호스트 앱이 직접 `FBAudienceNetwork`를 CocoaPods, Carthage, 또는
수동 binary target으로 링크해야 합니다. FAN SDK가 링크되지 않은 환경에서는
어댑터가 자동으로 비활성화되며, 링크하면 다음 빌드부터 활성화됩니다.

### AdFit 수동 통합 (SwiftPM을 쓸 수 없는 경우)

CocoaPods 등 SwiftPM이 아닌 환경에서 AdFit을 써야 한다면, AdFit SDK
바이너리와 어댑터 소스를 수동으로 추가합니다.

1. **AdFit SDK 다운로드** — [`adfit-spm`](https://github.com/adfit/adfit-spm)
   저장소에서 원하는 버전 태그의 `AdFitSDK.xcframework`
   (`Frameworks/AdFitSDK.xcframework`)를 내려받습니다.

2. **xcframework 임베드** — 받은 `AdFitSDK.xcframework`를 Xcode 타깃의
   *Frameworks, Libraries, and Embedded Content*에 추가하고 **Embed & Sign**
   으로 설정합니다.

3. **어댑터 소스 추가** — 이 저장소의
   `Sources/ExelBidMediationAdFit/` 안 `.swift` 파일들을 프로젝트에
   포함합니다.

> 가능하면 위 과정을 자동으로 처리하는 **SwiftPM 통합을 권장**합니다.

### iOS 배포 타깃

`ExelBidSDK` 자체는 iOS 13+를 지원합니다. 각 어댑터는 (ExelBidSDK, 기반
네트워크 SDK) 중 **최댓값**을 따릅니다 — 어댑터별 최소값은 위 표에
정리되어 있습니다. iOS 14+ 어댑터(예: AdMob)를 iOS 13 타깃 호스트에 링크하면
실패하므로, 어댑터 추가 전에 호스트의 배포 타깃을 올려야 합니다.

## 빠른 시작

앱 시작 시 사용하는 모듈을 등록합니다.

```swift
// AppDelegate.swift
import ExelBidSDK
import ExelBidMediationAdMob   // SwiftPM: 어댑터별 import
import ExelBidMediationFAN
// CocoaPods로 설치한 경우: import ExelBidMediationAdapter 하나만

func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions …) -> Bool {
    ExelBidMediationKit.shared.register(modules: [
        ExelBidBuiltInMediationModule.self,   // ExelBid 자체 어댑터 (항상 함께 등록)
        AdMobMediationModule.self,
        FANMediationModule.self
    ])
    return true
}
```

이후 광고 호출은 일반 SDK와 동일합니다.

```swift
import ExelBidSDK

let banner = EBMediatedBannerAd(
    adUnitId: "YOUR_AD_UNIT_ID",
    size: CGSize(width: 320, height: 50)
)
banner.onLoad = { print("낙찰 네트워크: \(banner.winningNetwork ?? "?")") }
view.addSubview(banner)
banner.load()
```

> 전면/네이티브/비디오 호출, 워터폴 이벤트, 옵션 설정, 자체 어댑터 작성 등
> 전체 사용법은
> [미디에이션 어댑터 사용자 가이드](https://github.com/onnuridmc/ExelBid_iOS_Swift/blob/main/MEDIATION_ADAPTER_GUIDE.md)
> 를 참고하세요.
