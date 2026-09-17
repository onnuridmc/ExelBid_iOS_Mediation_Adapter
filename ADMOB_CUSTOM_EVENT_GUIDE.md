# AdMob 커스텀 이벤트 연동 가이드

AdMob 미디에이션을 사용하는 앱에서 **ExelBid를 AdMob waterfall의 광고 소스로 추가**하는 방법을 안내합니다.

앱은 평소처럼 Google Mobile Ads(GMA) SDK로 광고를 요청합니다. waterfall에서 ExelBid 순서가 되면 GMA가 `ExelBidAdMobCustomEvent` 어댑터를 호출하고, 어댑터가 ExelBid 광고를 받아 GMA에 전달합니다. ExelBid 광고가 낙찰되어도 **앱의 AdMob 광고 코드는 바뀌지 않습니다.**

---

## 목차

1. [개요](#1-개요)
2. [요구 사항](#2-요구-사항)
3. [설치](#3-설치)
4. [앱 설정](#4-앱-설정)
5. [AdMob 콘솔 설정](#5-admob-콘솔-설정)
6. [타게팅 정보 전달](#6-타게팅-정보-전달)
7. [배너](#7-배너)
8. [전면](#8-전면)
9. [네이티브](#9-네이티브)
10. [노출 · 클릭 집계 기준](#10-노출--클릭-집계-기준)
11. [에러 코드](#11-에러-코드)
12. [테스트](#12-테스트)
13. [제약 사항](#13-제약-사항)
14. [문제 해결](#14-문제-해결)

---

## 1. 개요

### 1.1 어떤 모듈을 써야 하나요?

이 저장소에는 AdMob 관련 모듈이 두 개 있으며, **미디에이션 주체가 반대**입니다.

| 앱이 사용하는 미디에이션 | 사용할 모듈 | 호출 방향 |
|---|---|---|
| ExelBid 미디에이션 (`EBMediated*Ad`) | `ExelBidMediationAdMob` | ExelBid → AdMob |
| **AdMob 미디에이션** | **`ExelBidAdMobCustomEvent`** | **AdMob → ExelBid** |

이 문서는 `ExelBidAdMobCustomEvent`를 다룹니다. 두 모듈은 서로 독립이므로 커스텀 이벤트만 쓰는 앱은 `ExelBidMediationAdMob`를 추가할 필요가 없습니다.

### 1.2 지원 포맷

| AdMob 포맷 | 지원 |
|---|:-:|
| 배너 | ✅ |
| 전면 (Interstitial) | ✅ |
| 네이티브 | ✅ 이미지 광고 |
| 보상형 · 보상형 전면 · 앱 오프닝 | ❌ |

### 1.3 연동 방식

- AdMob **커스텀 이벤트(waterfall)** 방식입니다. 퍼블리셔가 AdMob 콘솔에서 직접 등록하며, 별도의 Google 파트너 계약이 필요 없습니다.
- 실시간 입찰(bidding)이 아니라 콘솔에 입력한 **eCPM 순서**에 따라 호출됩니다.
- ExelBid가 광고를 채우지 못하면 GMA가 자동으로 다음 네트워크를 시도합니다.

---

## 2. 요구 사항

| 항목 | 요구 사항 |
|---|---|
| iOS 배포 타깃 | 15.0 이상 |
| Swift / Xcode | Swift 5.9 / Xcode 15 이상 |
| Google Mobile Ads SDK | 12.0 이상, 14.0 미만 |
| ExelBid SDK (`ExelBid_iOS_Swift`) | 3.0.8 이상, 4.0 미만 |
| 의존성 관리자 | Swift Package Manager |

---

## 3. 설치

> `ExelBidAdMobCustomEvent`는 Swift Package Manager로만 제공합니다.

### 3.1 Xcode에서 추가

1. **File → Add Package Dependencies…**
2. URL에 `https://github.com/onnuridmc/ExelBid_iOS_Mediation_Adapter` 입력
3. Product 목록에서 **`ExelBidAdMobCustomEvent`** 를 앱 타깃에 추가

### 3.2 Package.swift에서 추가

```swift
dependencies: [
    .package(url: "https://github.com/onnuridmc/ExelBid_iOS_Swift", from: "3.0.8"),
    .package(url: "https://github.com/onnuridmc/ExelBid_iOS_Mediation_Adapter", from: "1.2.0"),
    .package(url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git",
             "12.0.0" ..< "14.0.0"),
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "GoogleMobileAds",
                     package: "swift-package-manager-google-mobile-ads"),
            .product(name: "ExelBidAdMobCustomEvent",
                     package: "ExelBid_iOS_Mediation_Adapter"),
        ]
    )
]
```

### 3.3 주의 사항

- `ExelBid_iOS_Swift`는 반드시 **`https://github.com/onnuridmc/ExelBid_iOS_Swift`** URL로 추가하세요. 다른 URL이나 로컬 경로로 추가하면 `ExelBidSDK`가 서로 다른 패키지로 인식되어 중복 정의 에러가 발생합니다.
- 앱이 `GoogleMobileAds`를 이미 특정 버전으로 고정했다면, 12.0 이상 14.0 미만 범위와 겹치도록 맞춰야 합니다.

---

## 4. 앱 설정

### 4.1 Google Mobile Ads SDK 기본 설정

[GMA SDK 시작 가이드](https://developers.google.com/admob/ios/quick-start)에 따라 다음을 먼저 설정합니다.

- `Info.plist`의 `GADApplicationIdentifier` (AdMob 앱 ID)
- 앱 시작 시 `MobileAds.shared.start(completionHandler:)` 호출
- `SKAdNetworkItems`

### 4.2 어댑터 클래스 참조 (권장)

GMA는 AdMob 콘솔에 입력한 **클래스 이름 문자열**로 어댑터를 찾습니다. 앱 코드에서 어댑터 클래스를 한 번도 참조하지 않으면 링크 과정에서 클래스가 제거될 수 있으므로, 앱 시작 시 한 번 참조해 두세요.

```swift
import GoogleMobileAds
import ExelBidAdMobCustomEvent

func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    _ = ExelBidCustomEvent.self   // 어댑터 클래스가 링크 단계에서 제거되지 않도록 참조
    MobileAds.shared.start(completionHandler: nil)
    return true
}
```

또는 Build Settings → **Other Linker Flags**에 `-ObjC`를 추가해도 됩니다.

### 4.3 ExelBid SDK 초기화

별도 초기화 코드가 필요 없습니다.

### 4.4 SKAdNetwork · ATT · 개인정보

- **SKAdNetwork**: ExelBid가 안내하는 SKAdNetwork ID를 `Info.plist`의 `SKAdNetworkItems`에 추가하세요. GMA용 항목과 같은 배열에 넣으면 됩니다.
- **ATT**: ExelBid SDK는 추적 권한 요청을 직접 띄우지 않습니다. 권한 요청은 앱에서 처리해 주세요. 권한이 없으면 광고 식별자 없이 요청합니다.
- **개인정보 매니페스트**: ExelBid SDK에 `PrivacyInfo.xcprivacy`가 포함되어 있어 추가 작업이 없습니다.

---

## 5. AdMob 콘솔 설정

### 5.1 준비물

| 항목 | 설명 |
|---|---|
| AdMob 광고 단위 | 배너 · 전면 · 네이티브 각각의 AdMob 광고 단위 |
| ExelBid 광고 단위 ID | **포맷별로 발급**받은 ExelBid 광고 단위 ID |
| eCPM | waterfall에서 ExelBid의 순서를 정할 금액 |

### 5.2 등록 절차

1. AdMob 콘솔 → **미디에이션** → **미디에이션 그룹 만들기**
2. **광고 형식**(배너 / 전면 광고 / 네이티브)과 **플랫폼 iOS** 선택
3. 그룹을 적용할 **AdMob 광고 단위** 추가
4. 폭포식 구조(Waterfall) 광고 소스에서 **커스텀 이벤트 추가**
5. 라벨(예: `ExelBid`)과 **eCPM** 입력
6. 광고 단위 매핑에 아래 값을 입력하고 저장

| 콘솔 입력란 | 입력 값 |
|---|---|
| **Class Name** | `ExelBidCustomEvent` |
| **Parameter** | 해당 포맷의 **ExelBid 광고 단위 ID** |

> 콘솔 메뉴 이름은 Google 정책에 따라 바뀔 수 있습니다.

### 5.3 입력 규칙

- **Class Name**은 대소문자까지 정확히 `ExelBidCustomEvent`로 입력합니다. 모듈 이름을 붙이지 않습니다(`ExelBidAdMobCustomEvent.ExelBidCustomEvent` ❌).
- **Parameter**에는 ExelBid 광고 단위 ID **문자열 하나만** 입력합니다. JSON이나 `key=value` 형식이 아닙니다.
- 배너 · 전면 · 네이티브 모두 **Class Name은 같고**, Parameter만 포맷에 맞는 ExelBid 광고 단위 ID로 입력합니다.

---

## 6. 타게팅 정보 전달

키워드 · 출생 연도 · 성별 등 요청별 타게팅 값은 GMA 요청에 **`ExelBidAdMobExtras`** 를 등록해 전달합니다. 등록하지 않으면 기본값으로 요청합니다.

### 6.1 설정 가능한 값 (`EBAdOptions`)

| 프로퍼티 | 타입 | 기본값 | 설명 |
|---|---|---|---|
| `keywords` | `[String: String]` | `[:]` | 키워드 타게팅. 예: `["channel": "sport"]` |
| `yearOfBirth` | `Int` | `0` | 출생 연도. `0`이면 전달하지 않음 |
| `gender` | `Gender` | `.unspecified` | `.male` / `.female` / `.unspecified` |
| `location` | `CLLocation?` | `nil` | 위치 |
| `coppa` | `Bool` | `false` | COPPA 적용 요청 여부 |
| `testing` | `Bool` | `false` | ExelBid 테스트 모드 요청 |

### 6.2 Swift

```swift
import GoogleMobileAds
import ExelBidSDK
import ExelBidAdMobCustomEvent

func makeRequest() -> Request {
    let extras = ExelBidAdMobExtras()
    extras.options.keywords = ["channel": "sport"]
    extras.options.yearOfBirth = 1990
    extras.options.gender = .female

    let request = Request()
    request.register(extras)
    return request
}
```

이미 만들어 둔 `EBAdOptions`가 있으면 `ExelBidAdMobExtras(options: myOptions)`로 전달할 수 있습니다.

### 6.3 Objective-C

```objc
@import GoogleMobileAds;
@import ExelBidSDK;
@import ExelBidAdMobCustomEvent;

- (GADRequest *)makeRequest {
    ExelBidAdMobExtras *extras = [[ExelBidAdMobExtras alloc] init];
    extras.options.keywords = @{ @"channel": @"sport" };
    extras.options.yearOfBirth = 1990;
    extras.options.gender = GenderFemale;

    GADRequest *request = [GADRequest request];
    [request registerAdNetworkExtras:extras];
    return request;
}
```

---

## 7. 배너

### 7.1 앱 코드

일반 AdMob 배너 코드와 같습니다.

**Swift**

```swift
import UIKit
import GoogleMobileAds

final class BannerViewController: UIViewController, BannerViewDelegate {

    private var bannerView: BannerView!

    override func viewDidLoad() {
        super.viewDidLoad()

        bannerView = BannerView(adSize: AdSizeBanner)
        bannerView.adUnitID = "ca-app-pub-XXXXXXXX/YYYYYYYY"   // AdMob 배너 광고 단위
        bannerView.rootViewController = self
        bannerView.delegate = self
        view.addSubview(bannerView)
        // 레이아웃 제약 생략

        bannerView.load(makeRequest())
    }

    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        print("배너 수신: \(bannerView.responseInfo?.loadedAdNetworkResponseInfo?.adSourceName ?? "-")")
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        print("배너 실패: \(error)")
    }
}
```

**Objective-C**

```objc
self.bannerView = [[GADBannerView alloc] initWithAdSize:GADAdSizeBanner];
self.bannerView.adUnitID = @"ca-app-pub-XXXXXXXX/YYYYYYYY";
self.bannerView.rootViewController = self;
self.bannerView.delegate = self;
[self.view addSubview:self.bannerView];
[self.bannerView loadRequest:[self makeRequest]];
```

### 7.2 동작

- **크기**: AdMob 배너 크기 영역 안에 ExelBid 광고가 맞춰져 가운데 정렬됩니다.
- **리프레시**: AdMob 광고 단위의 리프레시 설정을 따릅니다. ExelBid 자체 리프레시는 동작하지 않습니다.
- **노출**: 광고 로드가 완료된 시점에 집계됩니다([10](#10-노출--클릭-집계-기준) 참고).

---

## 8. 전면

### 8.1 앱 코드

**Swift**

```swift
import UIKit
import GoogleMobileAds

final class InterstitialViewController: UIViewController, FullScreenContentDelegate {

    private var interstitial: InterstitialAd?

    func loadInterstitial() {
        InterstitialAd.load(with: "ca-app-pub-XXXXXXXX/ZZZZZZZZ",   // AdMob 전면 광고 단위
                            request: makeRequest()) { [weak self] ad, error in
            if let error = error {
                print("전면 로드 실패: \(error)")
                return
            }
            ad?.fullScreenContentDelegate = self
            self?.interstitial = ad
        }
    }

    func showInterstitial() {
        interstitial?.present(from: self)
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        interstitial = nil
        loadInterstitial()   // 다음 표시를 위해 다시 로드
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        interstitial = nil
    }
}
```

**Objective-C**

```objc
[GADInterstitialAd loadWithAdUnitID:@"ca-app-pub-XXXXXXXX/ZZZZZZZZ"
                            request:[self makeRequest]
                  completionHandler:^(GADInterstitialAd *ad, NSError *error) {
    if (error) { return; }
    ad.fullScreenContentDelegate = self;
    self.interstitial = ad;
}];

[self.interstitial presentFromRootViewController:self];
```

### 8.2 동작

- **노출**: 전면 화면이 표시된 시점에 집계됩니다.
- **1회용**: 한 번 표시하고 닫은 광고는 다시 표시할 수 없습니다. 다음 표시 전에 새로 로드하세요.

---

## 9. 네이티브

### 9.1 앱 코드

일반 AdMob 네이티브처럼 `NativeAdView`로 렌더링합니다.

**Swift**

```swift
import UIKit
import GoogleMobileAds

final class NativeViewController: UIViewController, NativeAdLoaderDelegate {

    private var adLoader: AdLoader!
    @IBOutlet private weak var nativeAdView: NativeAdView!

    func loadNative() {
        adLoader = AdLoader(adUnitID: "ca-app-pub-XXXXXXXX/NNNNNNNN",   // AdMob 네이티브 광고 단위
                            rootViewController: self,
                            adTypes: [.native],
                            options: nil)
        adLoader.delegate = self
        adLoader.load(makeRequest())
    }

    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        (nativeAdView.headlineView as? UILabel)?.text = nativeAd.headline
        (nativeAdView.bodyView as? UILabel)?.text = nativeAd.body
        (nativeAdView.advertiserView as? UILabel)?.text = nativeAd.advertiser
        (nativeAdView.iconView as? UIImageView)?.image = nativeAd.icon?.image
        (nativeAdView.callToActionView as? UIButton)?.setTitle(nativeAd.callToAction, for: .normal)

        // 메인 이미지는 MediaView로 표시합니다.
        nativeAdView.mediaView?.mediaContent = nativeAd.mediaContent

        // CTA 버튼은 탭을 직접 받지 않도록 설정합니다. (9.4 참고)
        nativeAdView.callToActionView?.isUserInteractionEnabled = false

        nativeAdView.bodyView?.isHidden = nativeAd.body == nil
        nativeAdView.iconView?.isHidden = nativeAd.icon == nil
        nativeAdView.advertiserView?.isHidden = nativeAd.advertiser == nil

        // 에셋을 모두 채운 뒤 마지막에 할당합니다.
        nativeAdView.nativeAd = nativeAd
    }

    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        print("네이티브 실패: \(error)")
    }
}
```

**Objective-C**

```objc
- (void)adLoader:(GADAdLoader *)adLoader didReceiveNativeAd:(GADNativeAd *)nativeAd {
    ((UILabel *)self.nativeAdView.headlineView).text = nativeAd.headline;
    ((UILabel *)self.nativeAdView.bodyView).text = nativeAd.body;
    ((UIImageView *)self.nativeAdView.iconView).image = nativeAd.icon.image;
    [((UIButton *)self.nativeAdView.callToActionView) setTitle:nativeAd.callToAction
                                                      forState:UIControlStateNormal];
    self.nativeAdView.mediaView.mediaContent = nativeAd.mediaContent;
    self.nativeAdView.callToActionView.userInteractionEnabled = NO;
    self.nativeAdView.nativeAd = nativeAd;
}
```

### 9.2 에셋

| GMA `NativeAd` | 내용 | 비고 |
|---|---|---|
| `headline` | 제목 | |
| `body` | 설명 | |
| `callToAction` | CTA 문구 | |
| `icon` | 아이콘 이미지 | |
| `images` / `mediaContent` | 메인 이미지 | |
| `starRating` | 평점 | 0~5 범위일 때만 전달 |
| `price` | 가격 | |
| `advertiser` | 광고주 | |
| `store` | — | 항상 `nil` |

GMA에 대응 프로퍼티가 없는 에셋은 **`extraAssets`** 에 `String` 값으로 들어 있습니다. 값이 없는 에셋은 포함되지 않습니다.

| `extraAssets` 키 | 내용 |
|---|---|
| `desc2` | 보조 설명 |
| `displayurl` | 표시 URL |
| `phone` | 전화번호 |
| `address` | 주소 |
| `logo` | 로고 이미지 URL |
| `likes` | 좋아요 수 |
| `downloads` | 다운로드 수 |
| `saleprice` | 할인가 |

```swift
if let desc2 = nativeAd.extraAssets?["desc2"] as? String {
    secondaryLabel.text = desc2
}
```

### 9.3 이미지

- 기본 설정에서는 아이콘과 메인 이미지를 **미리 받아서** 전달합니다. `nativeAd.icon?.image`와 `MediaView`를 그대로 쓰면 됩니다.
- `NativeAdImageAdLoaderOptions`의 `isImageLoadingDisabled`를 `true`로 설정하면 이미지를 받지 않고 **URL만** 전달합니다(`nativeAd.icon?.imageURL`, `nativeAd.images?.first?.imageURL`). 이때 `MediaView`는 비어 있으므로 앱에서 URL로 이미지를 표시해야 합니다.
- 이미지 다운로드에 실패해도 광고 로드는 성공하며, 해당 이미지만 `nil`입니다.
- 메인 이미지의 가로세로 비율은 `nativeAd.mediaContent.aspectRatio`로 확인할 수 있습니다.

### 9.4 클릭 · 노출과 레이아웃 주의 사항

클릭과 노출은 어댑터가 자동으로 처리합니다. 앱에서 따로 호출할 코드는 없습니다.

- **클릭**: `NativeAdView` 영역 어디를 탭해도 광고 클릭으로 처리되고, 랜딩 페이지(앱스토어는 인앱 화면)가 열립니다. 에셋별로 클릭을 구분하지 않습니다.
- **노출**: 광고가 렌더링된 시점에 집계됩니다.

광고가 올바르게 동작하도록 다음을 지켜 주세요.

- CTA 버튼의 **`isUserInteractionEnabled`를 `false`** 로 설정하세요.
- `nativeAdView.nativeAd = nativeAd`는 **에셋을 모두 채운 뒤 마지막에** 할당하세요.
- 광고가 표시된 뒤 `NativeAdView`에 서브뷰를 새로 추가하지 마세요. 추가한 뷰 영역은 광고 클릭으로 인식되지 않습니다.
- 메인 이미지는 `imageView`가 아닌 **`MediaView`** 로 표시하세요.

### 9.5 AdChoices

- ExelBid 광고 정보 아이콘이 AdChoices 영역에 표시됩니다. 아이콘을 탭하면 광고 정보 페이지가 열리며, 광고 클릭으로 집계되지 않습니다.
- 광고 정보가 없는 광고는 아이콘이 표시되지 않습니다.

---

## 10. 노출 · 클릭 집계 기준

ExelBid와 AdMob에 같은 시점으로 노출 · 클릭을 보고합니다.

| 포맷 | 노출 시점 | 클릭 |
|---|---|---|
| 배너 | 광고 로드 완료 | 광고 클릭 시 |
| 전면 | 전면 화면 표시 | 광고 클릭 시 |
| 네이티브 | 광고 렌더링 | 광고 영역 클릭 시 |

집계가 서로 다를 수 있는 경우는 다음과 같습니다.

- **배너**: 노출은 화면 표시가 아닌 **로드 완료** 기준이므로, 화면 밖에 있는 배너도 노출로 집계됩니다. 또한 AdMob이 대기 시간 초과로 다음 네트워크로 넘어간 뒤 ExelBid 로드가 끝나면 ExelBid에만 노출이 집계될 수 있습니다.
- **네이티브**: ExelBid의 가시성 노출(광고 영역 50% · 100% 노출)은 ExelBid에만 집계됩니다.

---

## 11. 에러 코드

로드에 실패하면 GMA는 다음 네트워크를 시도합니다. 네트워크별 에러는 `responseInfo.adNetworkInfoArray`에서 확인할 수 있습니다.

**어댑터 에러** — 도메인 `com.exelbid.admob.customevent`

| 코드 | 원인 | 조치 |
|---|---|---|
| `1001` | AdMob 콘솔의 **Parameter가 비어 있음** | 해당 광고 단위 매핑에 ExelBid 광고 단위 ID 입력 |

**ExelBid SDK 에러** — 도메인 `com.motivi.exelbid.error`

| 코드 | 의미 |
|---|---|
| `1` | 광고 단위 ID가 올바르지 않음 |
| `2` | 광고 없음 (no fill) |
| `3` | 네트워크 오류 |
| `4` | 서버 오류 응답 |
| `5` | 응답 해석 실패 |
| `9` | 로드되지 않은 광고 표시 시도 |
| `10` | 요청 취소 |

---

## 12. 테스트

### 12.1 Google 샘플 테스트 광고 단위는 사용할 수 없습니다

Google 샘플 테스트 광고 단위(`ca-app-pub-3940256099942544/...`)는 미디에이션 그룹을 거치지 않아 **커스텀 이벤트가 호출되지 않습니다.** 반드시 실제 AdMob 광고 단위로 테스트하세요.

### 12.2 테스트 절차

1. 커스텀 이벤트를 등록한 미디에이션 그룹과 **실제 AdMob 광고 단위**를 준비합니다.
2. 테스트 기기를 등록합니다.
   ```swift
   MobileAds.shared.requestConfiguration.testDeviceIdentifiers = ["<기기 ID>"]
   ```
3. ExelBid가 먼저 호출되도록 테스트 그룹에서 **ExelBid eCPM을 가장 높게** 설정하거나, ExelBid만 넣은 그룹을 따로 만듭니다.
4. ExelBid 테스트 모드로 요청하려면 extras에 `testing = true`를 설정합니다.
   ```swift
   extras.options.testing = true
   ```
5. 어떤 네트워크가 호출되고 광고를 채웠는지 확인합니다([12.3](#123-waterfall-순서와-결과-확인)).

> AdMob 콘솔 설정은 저장 후 반영되기까지 시간이 걸릴 수 있습니다.

### 12.3 waterfall 순서와 결과 확인

AdMob 광고만 표시된다면, 먼저 **ExelBid 순서까지 도달했는지**와 **ExelBid가 성공 · 실패했는지**를 확인하세요. AdMob 네트워크는 waterfall에서 실시간 eCPM으로 함께 경쟁하므로, ExelBid보다 앞선 순서에서 광고를 채우면 ExelBid는 호출되지 않습니다.

**① 응답 정보(`ResponseInfo`)로 시도 순서 확인**

GMA는 광고 요청마다 시도한 네트워크 목록을 순서대로 제공합니다. 성공했을 때는 광고 객체의 `responseInfo`, 실패했을 때는 에러의 `userInfo`에서 꺼낼 수 있습니다.

```swift
import GoogleMobileAds

func printWaterfall(_ info: ResponseInfo?) {
    guard let info = info else {
        print("[Waterfall] 응답 정보 없음")
        return
    }
    let loaded = info.loadedAdNetworkResponseInfo
    print("[Waterfall] 광고를 채운 소스: \(loaded?.adSourceName ?? "없음")")

    for (index, network) in info.adNetworkInfoArray.enumerated() {
        let result: String
        if let error = network.error as NSError? {
            result = "실패 \(error.domain) code=\(error.code) \(error.localizedDescription)"
        } else if network.adSourceInstanceID == loaded?.adSourceInstanceID {
            result = "성공 (광고 표시)"
        } else {
            result = "에러 없음"
        }
        print(String(format: "[Waterfall] %d. %@ / %@ — %@ (%.2fs)",
                     index + 1,
                     network.adSourceName ?? "-",
                     network.adNetworkClassName,
                     result,
                     network.latency))
    }
}

// 성공
func bannerViewDidReceiveAd(_ bannerView: BannerView) {
    printWaterfall(bannerView.responseInfo)
}

// 실패
func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
    printWaterfall((error as NSError).userInfo[GADErrorUserInfoKeyResponseInfo] as? ResponseInfo)
}
```

전면은 `InterstitialAd.load` 완료 블록의 `ad?.responseInfo` 또는 `error`, 네이티브는 `nativeAd.responseInfo` 또는 `adLoader(_:didFailToReceiveAdWithError:)`의 `error`에 같은 방법을 쓰면 됩니다.

| 결과 | 의미 |
|---|---|
| 목록에 ExelBid 커스텀 이벤트가 없음 | ExelBid 순서 전에 다른 네트워크가 광고를 채웠거나, 미디에이션 그룹 설정이 이 광고 단위에 적용되지 않음 |
| ExelBid 항목이 에러와 함께 있음 | ExelBid까지 호출되었지만 실패. 에러 코드는 [11](#11-에러-코드) 참고 |
| ExelBid 항목이 광고를 채운 소스임 | ExelBid 광고가 표시됨 |

**② Ad Inspector로 확인**

테스트 기기로 등록된 기기에서 GMA의 Ad Inspector를 열면, 광고 단위별 요청 기록과 waterfall 결과를 화면에서 볼 수 있습니다.

```swift
MobileAds.shared.presentAdInspector(from: self) { error in
    if let error = error { print("Ad Inspector 열기 실패: \(error)") }
}
```

### 12.4 네이티브 광고 검사기 끄기

테스트 광고에 표시되는 AdMob 네이티브 광고 검사기 오버레이를 끄려면 `Info.plist`에 다음을 추가합니다.

```xml
<key>GADNativeAdValidatorEnabled</key>
<false/>
```

### 12.5 체크리스트

- [ ] 콘솔 Class Name이 `ExelBidCustomEvent`로 입력됨
- [ ] 포맷별 Parameter에 해당 포맷의 ExelBid 광고 단위 ID가 입력됨
- [ ] 앱 시작 시 `_ = ExelBidCustomEvent.self` 참조 또는 `-ObjC` 적용
- [ ] `responseInfo`에서 ExelBid 커스텀 이벤트 시도가 확인됨
- [ ] 배너: 광고가 표시되고 클릭 시 랜딩이 열림
- [ ] 전면: 표시 · 닫기 후 다시 로드해 표시됨
- [ ] 네이티브: 에셋과 메인 이미지가 표시되고, 광고 영역 탭 시 랜딩이 열림
- [ ] 네이티브: AdChoices 아이콘 탭 시 광고 정보 페이지가 열림

---

## 13. 제약 사항

| 항목 | 내용 |
|---|---|
| 포맷 | 보상형 · 보상형 전면 · 앱 오프닝 · 영상 네이티브 미지원 |
| 설치 | Swift Package Manager만 지원 |
| 네이티브 클릭 | 광고 영역 전체가 하나의 클릭 영역 (에셋별 구분 없음) |
| 네이티브 `logo` | 이미지가 아닌 URL 문자열로 `extraAssets`에 전달 |
| 네이티브 `store` | 항상 `nil` |

---

## 14. 문제 해결

| 증상 | 확인 사항 |
|---|---|
| AdMob 광고만 표시됨 / ExelBid가 호출되지 않음 | Google 샘플 테스트 광고 단위를 쓰고 있지 않은지 확인하세요([12.1](#121-google-샘플-테스트-광고-단위는-사용할-수-없습니다)). [12.3](#123-waterfall-순서와-결과-확인)의 방법으로 ExelBid까지 호출되었는지, 성공 · 실패했는지 확인하세요. 호출되지 않았다면 미디에이션 그룹의 광고 형식 · 플랫폼 · 광고 단위 매핑과 eCPM 순서를 확인하세요. |
| 어댑터 클래스를 찾지 못한다는 에러 | Class Name이 `ExelBidCustomEvent`인지, 앱 시작 시 클래스를 참조했는지 확인하세요([4.2](#42-어댑터-클래스-참조-권장)). |
| 에러 `1001` | 콘솔 Parameter에 ExelBid 광고 단위 ID를 입력하세요. |
| 에러 `2` (no fill) | 포맷에 맞는 ExelBid 광고 단위 ID인지 확인하세요. |
| 에러 `3`, `4` | 기기 네트워크 상태를 확인하세요. |
| 배너 광고가 잘려 보임 | AdMob 광고 단위 크기와 ExelBid 광고 단위 크기를 맞추세요. |
| 네이티브 메인 이미지가 보이지 않음 | `imageView`가 아닌 `MediaView`에 `mediaContent`를 할당했는지, 이미지 로딩을 끄지 않았는지 확인하세요. |
| 네이티브 클릭이 되지 않음 | CTA 버튼의 `isUserInteractionEnabled`가 `false`인지, 광고 표시 후 추가한 서브뷰가 광고를 덮고 있지 않은지 확인하세요. |
| 전면이 두 번째에 표시되지 않음 | 전면 광고는 1회용입니다. 닫힌 뒤 다시 로드하세요. |
