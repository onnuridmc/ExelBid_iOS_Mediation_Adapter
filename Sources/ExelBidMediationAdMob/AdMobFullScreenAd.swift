// Compatible with: Google Mobile Ads SDK 12.x

import Foundation
import UIKit
import GoogleMobileAds

/// Shared driver for AdMob **fullscreen ("전면")** ads.
///
/// AdMob serves a fullscreen slot through a single `InterstitialAd` object
/// regardless of the creative type — the unit can return a **display
/// (image / banner) creative or a video creative**, and AdMob renders
/// whichever it gets through the same object. There is no SDK-level way to
/// request "video only"; the ad unit configuration decides.
///
/// Both the interstitial and the video mediation adapters wrap this driver;
/// they differ only in which mediation protocol they satisfy and the one
/// extra callback each adds on top of the shared lifecycle:
/// - `AdMobInterstitialAdapter` → `EBInterstitialMediationAdapter` (+ `onClickFinish`)
/// - `AdMobVideoAdapter` → `EBVideoMediationAdapter` (+ `onProgress`)
///
/// AdMob bridges click and dismissal but exposes no quartile callbacks, so
/// the video adapter approximates progress from `onDidDisappear`.
final class AdMobFullScreenAd: NSObject {

    var onWillAppear: (() -> Void)?
    var onDidAppear: (() -> Void)?
    var onWillDisappear: (() -> Void)?
    var onDidDisappear: (() -> Void)?
    var onClick: (() -> Void)?

    private var ad: GoogleMobileAds.InterstitialAd?

    /// Load the fullscreen ad. Throws to let the caller advance the
    /// waterfall. Retains the loaded ad until `present(from:)`.
    func load(unitId: String) async throws {
        let loaded = try await GoogleMobileAds.InterstitialAd.load(
            with: unitId, request: Request()
        )
        await MainActor.run {
            loaded.fullScreenContentDelegate = self
            self.ad = loaded
        }
    }

    @MainActor
    func present(from viewController: UIViewController) {
        ad?.present(from: viewController)
    }

    func cancel() {
        ad = nil
    }
}

extension AdMobFullScreenAd: FullScreenContentDelegate {
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        onWillAppear?()
    }
    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        onDidAppear?()
    }
    func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        onWillDisappear?()
    }
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        onDidDisappear?()
    }
    func adDidRecordClick(_ ad: FullScreenPresentingAd) {
        onClick?()
    }
}
