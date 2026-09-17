// Compatible with: Google Mobile Ads SDK 12.x / 13.x

import Foundation
import UIKit
import ExelBidSDK
import GoogleMobileAds

/// AdMob **custom event** adapter: lets an AdMob-mediated host app call
/// ExelBid as one network in its waterfall.
///
/// This is the opposite direction from `ExelBidMediationAdMob`, which lets
/// ExelBid's own mediation call AdMob.
///
/// Publisher setup in the AdMob console (Mediation → custom event):
/// - **Class Name**: `ExelBidCustomEvent` (the `@objc` name below — GMA looks
///   the class up through the Objective-C runtime, so the Swift module
///   prefix must not leak into it).
/// - **Parameter**: the ExelBid ad unit id.
@objc(ExelBidCustomEvent)
public final class ExelBidCustomEvent: NSObject, MediationAdapter {

    /// Adapter version, independent of the ExelBid SDK version.
    private static let version = VersionNumber(majorVersion: 1, minorVersion: 0, patchVersion: 0)

    // MARK: - MediationAdapter (required)

    public static func adapterVersion() -> VersionNumber { version }

    public static func adSDKVersion() -> VersionNumber {
        parseVersion(ExelBid.shared.sdkVersion)
    }

    public static func networkExtrasClass() -> (any AdNetworkExtras.Type)? {
        ExelBidAdMobExtras.self
    }

    public override init() { super.init() }

    // MARK: - MediationAdapter (optional)

    /// ExelBid needs no SDK-level bootstrap — `ExelBid.shared` is ready on
    /// first use — so setup completes immediately.
    ///
    /// GMA calls this on a background queue.
    public static func setUp(
        with configuration: MediationServerConfiguration,
        completionHandler: @escaping (Error?) -> Void
    ) {
        completionHandler(nil)
    }

    // MARK: - Banner

    /// Retains the in-flight ad; GMA drops its reference to the adapter once
    /// loading finishes.
    private var bannerAd: ExelBidMediationBannerAd?

    /// Called on the main thread; `completionHandler` must be called back on
    /// the main thread too.
    public func loadBanner(
        for adConfiguration: MediationBannerAdConfiguration,
        completionHandler: @escaping GADMediationBannerLoadCompletionHandler
    ) {
        let adUnitId: String
        do {
            adUnitId = try CustomEventCredentials.adUnitId(from: adConfiguration)
        } catch {
            _ = completionHandler(nil, error)
            return
        }

        // The slot size AdMob asks for. ExelBid forwards it as vw / vh and
        // clamps the creative to it.
        let size = cgSize(for: adConfiguration.adSize)

        MainActor.assumeIsolated {
            let ad = ExelBidMediationBannerAd(
                adUnitId: adUnitId,
                adSize: size,
                options: CustomEventCredentials.options(from: adConfiguration)
            )
            bannerAd = ad
            ad.load(completionHandler: completionHandler)
        }
    }

    // MARK: - Interstitial

    private var interstitialAd: ExelBidMediationInterstitialAd?

    /// Called on the main thread; `completionHandler` must be called back on
    /// the main thread too.
    public func loadInterstitial(
        for adConfiguration: MediationInterstitialAdConfiguration,
        completionHandler: @escaping GADMediationInterstitialLoadCompletionHandler
    ) {
        let adUnitId: String
        do {
            adUnitId = try CustomEventCredentials.adUnitId(from: adConfiguration)
        } catch {
            _ = completionHandler(nil, error)
            return
        }

        let ad = ExelBidMediationInterstitialAd(
            adUnitId: adUnitId,
            options: CustomEventCredentials.options(from: adConfiguration)
        )
        interstitialAd = ad
        ad.load(completionHandler: completionHandler)
    }

    // MARK: - Native

    private var nativeAd: ExelBidMediationNativeAd?

    /// Called on the main thread; `completionHandler` must be called back on
    /// the main thread too.
    public func loadNativeAd(
        for adConfiguration: MediationNativeAdConfiguration,
        completionHandler: @escaping GADMediationNativeLoadCompletionHandler
    ) {
        let adUnitId: String
        do {
            adUnitId = try CustomEventCredentials.adUnitId(from: adConfiguration)
        } catch {
            _ = completionHandler(nil, error)
            return
        }

        let ad = ExelBidMediationNativeAd(
            adUnitId: adUnitId,
            options: CustomEventCredentials.options(from: adConfiguration),
            imageLoadingDisabled: NativeAssetMapping.isImageLoadingDisabled(adConfiguration.options)
        )
        nativeAd = ad
        ad.load(completionHandler: completionHandler)
    }

    // MARK: - Helpers

    /// "3.0.9" → VersionNumber(3, 0, 9). Missing components read as 0.
    private static func parseVersion(_ string: String) -> VersionNumber {
        let parts = string.split(separator: ".").map { Int($0) ?? 0 }
        return VersionNumber(
            majorVersion: parts.count > 0 ? parts[0] : 0,
            minorVersion: parts.count > 1 ? parts[1] : 0,
            patchVersion: parts.count > 2 ? parts[2] : 0
        )
    }
}
