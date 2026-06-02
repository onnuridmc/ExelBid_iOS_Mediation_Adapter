// Compatible with: Google Mobile Ads SDK 12.x
// Last verified: 2026-05-21
//
// AdMob's fullscreen video offerings are RewardedAd (incentivised) and
// RewardedInterstitialAd. This adapter uses `RewardedAd` since v3's
// `EBVideoAd` is the closest semantic match (fullscreen video with
// VAST-style progress) and ExelBid does not currently differentiate
// reward grants from the SDK surface. If you need true rewarded-grant
// signaling, register a custom adapter (see USAGE_GUIDE §7).

import Foundation
import UIKit
import ExelBidSDK
import GoogleMobileAds

public final class AdMobVideoAdapter: NSObject, EBVideoMediationAdapter {

    public static let networkID = "admob"
    public static var isAvailable: Bool { true }

    public var onWillAppear: (() -> Void)?
    public var onDidAppear: (() -> Void)?
    public var onWillDisappear: (() -> Void)?
    public var onDidDisappear: (() -> Void)?
    public var onClick: (() -> Void)?
    public var onLeaveApp: (() -> Void)?
    public var onProgress: ((Int) -> Void)?

    private var rewarded: RewardedAd?

    public override init() { super.init() }

    public func load(
        unitId: String,
        rootViewController: UIViewController?,
        timeout: TimeInterval
    ) async throws {
        let ad = try await RewardedAd.load(with: unitId, request: Request())
        await MainActor.run {
            ad.fullScreenContentDelegate = self
            self.rewarded = ad
        }
    }

    @MainActor
    public func present(from viewController: UIViewController) {
        guard let ad = rewarded else { return }
        // AdMob does not expose quartile callbacks for RewardedAd; fire
        // start/complete approximations from the lifecycle hooks below.
        ad.present(from: viewController) { [weak self] in
            // Reward earned == playback completion in our semantics.
            self?.onProgress?(100)
        }
        onProgress?(0)
    }

    public func cancel() {
        rewarded = nil
    }
}

extension AdMobVideoAdapter: FullScreenContentDelegate {
    public func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        onWillAppear?()
    }
    public func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        onDidAppear?()
    }
    public func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        onWillDisappear?()
    }
    public func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        onDidDisappear?()
    }
    public func adDidRecordClick(_ ad: FullScreenPresentingAd) {
        onClick?()
        onLeaveApp?()
    }
}
