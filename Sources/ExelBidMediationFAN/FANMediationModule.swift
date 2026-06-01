import Foundation
import ExelBidSDK

public enum FANMediationModule: MediationModule {
    public static func register(in registry: MediationRegistry) {
        registry.register(banner: FANBannerAdapter.self)
        registry.register(interstitial: FANInterstitialAdapter.self)
        registry.register(native: FANNativeAdapter.self)
        registry.register(video: FANVideoAdapter.self)
    }
}
