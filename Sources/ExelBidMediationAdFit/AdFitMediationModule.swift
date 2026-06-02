import Foundation
import ExelBidSDK

public enum AdFitMediationModule: EBMediationModule {
    public static func register(in registry: EBMediationRegistry) {
        registry.register(banner: AdFitBannerAdapter.self)
        registry.register(interstitial: AdFitInterstitialAdapter.self)
        registry.register(native: AdFitNativeAdapter.self)
        // AdFit SDK has no fullscreen video format — video adapter is
        // intentionally omitted. Hosts that need video mediation should
        // register a custom adapter (see USAGE_GUIDE §7).
    }
}
