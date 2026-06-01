# exelbid-ios-sdk-mediation

Third-party network adapters for [ExelBid iOS SDK v3](../exelbid-ios-sdk-v3)
mediation. Each adapter is shipped as a separate SwiftPM library so host
apps only link the third-party ad SDKs they actually use.

This repo intentionally does **not** contain the mediation orchestrator,
protocols, or registry — those are bundled into the `ExelBidSDK`
product (in the main `exelbid-ios-sdk-v3` repo) so every SDK consumer
gets the mediation API automatically. Adapters here are thin bridges
between that contract and each network's iOS SDK.

## Adapter inventory

| Module | Network | Banner | Interstitial | Native | Video | Underlying SDK | Min iOS | Distribution |
|---|---|:-:|:-:|:-:|:-:|---|---|---|
| `ExelBidMediationAdMob` | Google AdMob | ✅ | ✅ | ✅ | ✅ (Rewarded) | `GoogleMobileAds` 12.x | 14 | SwiftPM |
| `ExelBidMediationFAN` | Facebook Audience Network | ✅ | ✅ | ✅ | ✅ (Rewarded) | `FBAudienceNetwork` 6.x+ | 14 | CocoaPods (host links) |
| `ExelBidMediationAdFit` | Kakao AdFit | ✅ | ✅ | ✅ | — | `AdFitSDK` 3.x | 13 | CocoaPods (host links) |
| `ExelBidMediationPangle` | ByteDance Pangle | 🟡 placeholder | TBD | TBD | TBD | `PAGAdSDK` 5.x | 12 | CocoaPods (host links) |
| `ExelBidMediationAppLovin` | AppLovin (SDK direct) | 🟡 placeholder | TBD | TBD | TBD | `AppLovinSDK` 12.x+ | 12 | CocoaPods (host links) |
| `ExelBidMediationDT` | Digital Turbine / Fyber | 🟡 placeholder | TBD | TBD | TBD | `IASDKCore` 8.x | 13 | CocoaPods (host links) |
| `ExelBidMediationTNK` | TNK Factory | 🟡 placeholder | TBD | TBD | TBD | `TnkAdSdk` 7.x | 11 | CocoaPods (host links) |
| `ExelBidMediationTargetPick` | MezzoMedia TargetPick | 🟡 placeholder | TBD | TBD | TBD | `ADMixerZ` | 11 | CocoaPods (host links) |

**Notes on Phase 4 placeholders** (🟡):

Pangle / AppLovin / DT / TNK / TargetPick modules ship as
**registration scaffolds** — the network ID is wired to
`MediationRegistry`, the module's `register(in:)` runs, and the server
waterfall routes correctly. But the adapter's `load(...)` currently
throws because the concrete bridge to each network's SDK is not yet
implemented. `isAvailable` is `false` until that bridge is written.
The orchestrator treats unavailable adapters the same as unregistered
ones (`WaterfallEvent.lost(.adapterNotRegistered)`) and advances.

To fill in a placeholder:
1. Link the underlying third-party SDK (CocoaPods / binary target).
2. Replace the `#if canImport(<SDKModule>)` block in
   `<Network>BannerAdapter.swift` with a real implementation
   modelled on `AdMobBannerAdapter`.
3. Flip `isAvailable` to `true`.
4. Add a real-API integration test under
   `Tests/ExelBidMediationAdaptersTests/`.

Alternatively, hosts can register their own adapter implementing
`BannerMediationAdapter` directly — see
`exelbid-ios-sdk-v3/docs/USAGE_GUIDE.md` §7.

**TargetPick — required configuration**

TargetPick requires `(publisherId, mediaId)` at SDK init. Call
`TargetPickMediationModule.configure(...)` **before**
`ExelBidMediationKit.shared.register(modules:)`:

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

**Notes on video adapters**:
- AdMob and FAN expose fullscreen video as their **rewarded** ad format
  (no separate VAST interstitial-video API). The video adapters here
  wrap `RewardedAd` / `FBRewardedVideoAd` accordingly; quartile
  progress is approximated (`onProgress(0)` at present,
  `onProgress(100)` on completion). Hosts that need true rewarded-grant
  signaling should register a custom adapter — see
  `exelbid-ios-sdk-v3/docs/USAGE_GUIDE.md` §7.
- AdFit's SDK does not ship a fullscreen video format, so
  `AdFitMediationModule` intentionally does not register a video
  adapter. The `"adfit"` entry in the server's video waterfall will be
  skipped with `WaterfallEvent.lost(.adapterNotRegistered)`.

The built-in ExelBid adapter is not here — it ships with the main SDK
as `ExelBidBuiltInMediationModule` (zero third-party dependencies).

### A note on FAN and AdFit

Facebook Audience Network and Kakao AdFit do **not** publish SwiftPM
packages. The adapter Swift files are wrapped in
`#if canImport(...)`, so they compile in SwiftPM-only environments as
no-op placeholders (`isAvailable == false`). To activate the real
adapter, the host app must link the third-party SDK itself via
CocoaPods, Carthage, or a manual binary target. Once `FBAudienceNetwork`
or `AdFitSDK` is linkable from the host's target, the adapter
automatically picks up the real implementation on the next build.

### iOS deployment target

`ExelBidSDK` itself supports iOS 13+. Each adapter inherits the
**maximum** of (ExelBidSDK, underlying network SDK) — the table above
lists the per-adapter minimum. Linking an iOS 14+ adapter
(e.g., AdMob) into a host that targets iOS 13 will fail at link time;
raise the host's deployment target before adding the adapter.

## Adding to a host app

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/exelbid/exelbid-ios-sdk-v3.git",
             from: "3.1.0"),
    .package(url: "https://github.com/exelbid/exelbid-ios-sdk-mediation.git",
             from: "1.0.0"),
],
targets: [
    .target(
        dependencies: [
            .product(name: "ExelBidSDK", package: "exelbid-ios-sdk-v3"),
            .product(name: "ExelBidMediationAdMob", package: "exelbid-ios-sdk-mediation"),
            .product(name: "ExelBidMediationFAN", package: "exelbid-ios-sdk-mediation"),
            // …only the ones you actually use
        ]
    )
]
```

```swift
// AppDelegate.swift
import ExelBidSDK
import ExelBidMediationAdMob
import ExelBidMediationFAN

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

```swift
// Anywhere:
import ExelBidSDK

let banner = MediatedBannerAd(
    adUnitId: "08377f76c8b3e46c4ed36c82e434da2b394a4dfa",
    size: CGSize(width: 320, height: 50)
)
banner.onLoad = { print("filled by: \(banner.winningNetwork ?? "?")") }
view.addSubview(banner)
banner.load()
```

## Building locally

While developing this repo, the `Package.swift` consumes
`exelbid-ios-sdk-v3` via a relative path (`../exelbid-ios-sdk-v3`).
For published releases the path is swapped for a versioned URL.

```bash
DEST=$(xcrun simctl list devices available | grep -E "iPhone [0-9]+ \(" \
       | head -1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')

xcodebuild -scheme ExelBidMediationAdMob \
  -destination "platform=iOS Simulator,id=$DEST" \
  build
```

Each adapter target requires its underlying third-party SDK in the
SwiftPM cache. First build pulls these — subsequent builds reuse them.

## Adding a new network adapter

1. Create `Sources/ExelBidMediation<Network>/`.
2. Implement `<Network>BannerAdapter` (and others as needed) conforming
   to the protocols from `ExelBidSDK`.
3. Add a `<Network>MediationModule` enum implementing `MediationModule`.
4. Add the product + target to `Package.swift` above.
5. Document version compatibility at the top of each adapter file.

See `Sources/ExelBidMediationAdMob/AdMobBannerAdapter.swift` for the
canonical example.

## Versioning

Adapters track the major version of their underlying SDK. When a
network ships a breaking change:

1. Update the SwiftPM dependency in `Package.swift`.
2. Update the adapter to the new API.
3. Update the "Compatible with:" header at the top of each adapter file.
4. Bump this package's minor version.
