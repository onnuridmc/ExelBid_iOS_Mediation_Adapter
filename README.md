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
| `ExelBidMediationAdMob` | Google AdMob | ✅ | ✅ | ✅ | ✅ (전면 비디오) | `GoogleMobileAds` 12.x–13.x | 14 | SwiftPM · CocoaPods |
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
> 어댑터 **1.1.9**는 `ExelBidSDK` **3.0.8 이상**(4.0 미만)을 요구합니다.

> ⚠️ **의존성 충돌 주의 — SDK와 어댑터는 같은 의존성 관리자로 통합하세요.**
> 어댑터는 `ExelBid_iOS_Swift`(미디에이션 코어)를 의존성으로 포함합니다.
> `ExelBidSDK`를 **SwiftPM으로 추가했다면 어댑터도 SwiftPM으로**,
> **CocoaPods로 추가했다면 어댑터도 CocoaPods로** 설치해야 합니다.
> 두 방식을 섞으면(예: SDK는 SPM, 어댑터는 Pod) `ExelBidSDK`·`GoogleMobileAds`가
> **두 번 링크되어 중복 심볼 / "Multiple commands produce" 빌드 에러**가 발생합니다.
>
> - **같은 채널 안에서는 중복 선언이 안전합니다.** 호스트가 이미 `ExelBid_iOS_Swift`를
>   추가했더라도, SwiftPM·CocoaPods가 동일 의존성을 자동으로 하나로 합칩니다
>   (별도로 제거할 필요 없음).
> - **SwiftPM은 패키지 URL(identity)로 동일성을 판단합니다.** 호스트와 어댑터가
>   반드시 같은 URL `https://github.com/onnuridmc/ExelBid_iOS_Swift` 를 사용해야 합니다.
>   호스트가 다른 URL이나 로컬 path로 SDK를 추가하면 `ExelBidSDK`가 서로 다른
>   패키지로 인식되어 **중복 정의 에러**가 납니다.

### Swift Package Manager

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/onnuridmc/ExelBid_iOS_Swift.git",
             from: "3.0.8"),
    .package(url: "https://github.com/onnuridmc/ExelBid_iOS_Mediation_Adapter.git",
             from: "1.1.9"),
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

> **참고 — 안 쓰는 어댑터의 SDK도 resolve(체크아웃)되지만, 빌드엔 포함되지
> 않습니다.** 어댑터 SDK 의존성은 패키지 레벨에 선언되어 있어, 호스트가 어떤
> product를 고르든 SwiftPM이 **모든 네트워크 SDK를 resolve** 합니다(예: AdFit
> 어댑터만 써도 `GoogleMobileAds`가 `Package.resolved`에 함께 pin 됨). 단,
> SwiftPM은 **앱 타깃이 실제로 의존하는 target만 컴파일·링크**하므로, 쓰지
> 않는 어댑터의 SDK는 **바이너리에 들어가지 않습니다**. 따라서 미사용 SDK가
> 체크아웃되어 있어도 **앱 크기·심볼에는 영향이 없고**, CocoaPods 등 다른
> 매니저와의 충돌도 그 자체로는 발생하지 않습니다(충돌은 *같은* SDK를 두
> 매니저로 동시에 **링크**할 때만 — 위 ⚠️ 경고 참고).
>
> 다만 미사용 SDK도 resolve되므로, 호스트가 같은 SDK(`GoogleMobileAds`·
> `AdFitSDK`)를 **다른 버전으로 이미 pin** 하고 있으면 해당 어댑터를 쓰지
> 않더라도 **버전 해석(resolve) 단계에서 충돌**할 수 있습니다. 이 경우 호스트와
> 어댑터의 SDK 버전 범위를 맞춰 주세요.

### CocoaPods

```ruby
# Podfile
pod 'ExelBid_Mediation_Adapter/AdMob', '~> 1.1.9'
pod 'ExelBid_Mediation_Adapter/FAN',   '~> 1.1.9'
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

### 네트워크 SDK 배포 채널 (직접 추가용 링크)

각 네트워크의 iOS SDK는 아래 채널로 배포됩니다. 위의 어댑터 설치(SwiftPM
product / CocoaPods subspec)를 사용하면 해당 SDK가 의존성으로 **자동 설치**
되므로 보통 이 표를 직접 쓸 일은 없습니다. 다만 SwiftPM·CocoaPods를 쓸 수
없거나, 이미 다른 경로로 SDK를 링크하고 있어 **프레임워크를 직접 추가**해야
하는 경우 아래 링크를 참고하세요.

| 네트워크 SDK | Swift Package Manager | CocoaPods | 직접 다운로드 (xcframework) |
|---|---|---|---|
| `GoogleMobileAds` (AdMob) | [`swift-package-manager-google-mobile-ads`](https://github.com/googleads/swift-package-manager-google-mobile-ads.git) · `"12.0.0" ..< "14.0.0"` · product `GoogleMobileAds` | `Google-Mobile-Ads-SDK` `>= 12.0, < 14.0` | [AdMob SDK 다운로드](https://developers.google.com/admob/ios/download) |
| `FBAudienceNetwork` (FAN) | ❌ 미제공 | `FBAudienceNetwork` `~> 6.0` | [Audience Network SDK 추가 가이드](https://developers.facebook.com/docs/audience-network/setting-up/platform-setup/ios/add-sdk/) |
| `AdFitSDK` (AdFit) | [`adfit-spm`](https://github.com/adfit/adfit-spm) · `from: 3.21.0` · product `AdFitSDK` | ❌ 미제공 | [`adfit-spm` › Frameworks/AdFitSDK.xcframework](https://github.com/adfit/adfit-spm/tree/main/Frameworks) |

### 프레임워크 직접(수동) 추가

SwiftPM·CocoaPods를 쓸 수 없는 환경에서는, 네트워크 SDK 바이너리
(`.xcframework`)와 이 저장소의 어댑터 소스를 직접 프로젝트에 넣어 통합할 수
있습니다. 공통 절차는 다음과 같습니다.

1. **SDK xcframework 다운로드** — 위 표의 *직접 다운로드* 링크에서 해당
   네트워크 SDK의 `.xcframework`(및 함께 배포되는 의존 프레임워크)를
   내려받습니다.
2. **xcframework 임베드** — Xcode 타깃의 *General › Frameworks, Libraries,
   and Embedded Content*에 추가하고 **Embed & Sign**으로 설정합니다.
3. **어댑터 소스 추가** — 이 저장소의 해당 어댑터 폴더(`Sources/ExelBidMediation*/`)
   안 `.swift` 파일들을 프로젝트에 포함합니다.
4. **미디에이션 코어** — `ExelBidSDK`(미디에이션 코어)는 호스트가 이미
   통합한 것을 그대로 사용합니다. 어댑터 소스만 같은 타깃에 추가하면 됩니다.

> 가능하면 위 과정을 자동으로 처리하는 **SwiftPM / CocoaPods 통합을 권장**
> 합니다. 직접 추가는 SDK 버전 업데이트·의존 프레임워크 관리를 모두 수동으로
> 해야 합니다.

네트워크별 세부 사항:

- **AdMob** — [AdMob SDK 다운로드 페이지](https://developers.google.com/admob/ios/download)
  의 zip에는 `GoogleMobileAds.xcframework` 외에 사용자 동의(UMP) 등 **의존
  프레임워크가 함께** 들어 있습니다. zip에 포함된 xcframework를 **모두**
  임베드해야 합니다. 어댑터 소스는 `Sources/ExelBidMediationAdMob/`.
- **FAN** — [Audience Network SDK 추가 가이드](https://developers.facebook.com/docs/audience-network/setting-up/platform-setup/ios/add-sdk/)
  에서 받은 zip에는 static·dynamic 두 종류의 `FBAudienceNetwork.xcframework`
  가 들어 있습니다. 프로젝트 구성에 맞는 쪽을 임베드하세요. 어댑터 소스는
  `Sources/ExelBidMediationFAN/`이며, `#if canImport(FBAudienceNetwork)`로
  가드되어 SDK가 링크된 다음 빌드부터 활성화됩니다(위 [FAN 통합 방식](#fan-통합-방식) 참고).
- **AdFit** — [`adfit-spm`](https://github.com/adfit/adfit-spm) 저장소에서
  원하는 버전 태그의 `Frameworks/AdFitSDK.xcframework`를 내려받아 임베드
  합니다. 어댑터 소스는 `Sources/ExelBidMediationAdFit/`.

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

## AdMob 네이티브 광고 검사기 끄기

AdMob 네이티브 광고를 **테스트 광고**로 띄우면, 레이아웃·정책 위반을 알려주는
**네이티브 광고 검사기(native ad validator)** 오버레이가 광고 위에 자동으로
표시됩니다. 실제(라이브) 광고에는 나타나지 않고 테스트 광고에서만 보입니다.

검사기를 끄려면 호스트 앱의 `Info.plist`에 다음 키를 추가합니다(Google Mobile
Ads SDK 7.68.0 이상 필요).

```xml
<key>GADNativeAdValidatorEnabled</key>
<false/>
```

> 끄면 테스트 광고에서 레이아웃 문제 알림이 더 이상 표시되지 않습니다. 자세한
> 내용은 [AdMob 네이티브 광고 검사기(iOS)](https://developers.google.com/admob/ios/native/validator?hl=ko)
> 문서를 참고하세요. (Android는
> [AndroidManifest 메타데이터](https://developers.google.com/admob/android/native/validator?hl=ko)로 설정)
