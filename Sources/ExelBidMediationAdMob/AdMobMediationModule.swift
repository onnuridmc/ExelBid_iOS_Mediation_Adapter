import Foundation
import ExelBidSDK

/// Module registration entry point for Google AdMob mediation.
/// Call once at app launch:
///
/// ```swift
/// ExelBidMediationKit.shared.register(modules: [AdMobMediationModule.self])
/// ```
public enum AdMobMediationModule: MediationModule {
    public static func register(in registry: MediationRegistry) {
        registry.register(banner: AdMobBannerAdapter.self)
        registry.register(interstitial: AdMobInterstitialAdapter.self)
        registry.register(native: AdMobNativeAdapter.self)
        registry.register(video: AdMobVideoAdapter.self)
    }
}
