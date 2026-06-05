import Foundation
import ExelBidSDK

public enum AdFitMediationModule: EBMediationModule {
    public static func register(in registry: EBMediationRegistry) {
        registry.register(banner: AdFitBannerAdapter.self)
        registry.register(native: AdFitNativeAdapter.self)
        // AdFit SDK provides only banner and native formats — it has no
        // fullscreen interstitial or video. Hosts that need those formats
        // should register a custom adapter (see the ExelBid iOS SDK docs).
    }
}
