import Foundation
import ExelBidSDK

public enum FANMediationModule: EBMediationModule {
    public static func register(in registry: EBMediationRegistry) {
        registry.register(banner: FANBannerAdapter.self)
        registry.register(interstitial: FANInterstitialAdapter.self)
        registry.register(native: FANNativeAdapter.self)
        registry.register(video: FANVideoAdapter.self)
    }
}
