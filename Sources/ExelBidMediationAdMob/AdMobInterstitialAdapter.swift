// Compatible with: Google Mobile Ads SDK 12.x
// Last verified: 2026-05-21

import Foundation
import UIKit
import ExelBidSDK
import GoogleMobileAds

/// Mediation adapter for Google AdMob fullscreen interstitials
/// (`InterstitialAd`). Bridges AdMob's `FullScreenContentDelegate` to
/// the closure callbacks the orchestrator expects.
public final class AdMobInterstitialAdapter: NSObject, EBInterstitialMediationAdapter {

    public static let networkID = "admob"
    public static var isAvailable: Bool { true }

    public var onWillAppear: (() -> Void)?
    public var onDidAppear: (() -> Void)?
    public var onWillDisappear: (() -> Void)?
    public var onDidDisappear: (() -> Void)?
    public var onClick: (() -> Void)?
    public var onLeaveApp: (() -> Void)?
    public var onClickFinish: (() -> Void)?

    private var interstitial: GoogleMobileAds.InterstitialAd?

    public override init() { super.init() }

    public func load(
        unitId: String,
        rootViewController: UIViewController?,
        timeout: TimeInterval
    ) async throws {
        let ad = try await GoogleMobileAds.InterstitialAd.load(with: unitId, request: Request())
        await MainActor.run {
            ad.fullScreenContentDelegate = self
            self.interstitial = ad
        }
    }

    @MainActor
    public func present(from viewController: UIViewController) {
        interstitial?.present(from: viewController)
    }

    public func cancel() {
        interstitial = nil
    }
}

extension AdMobInterstitialAdapter: FullScreenContentDelegate {
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
        // AdMob does not distinguish click from leave-app; fire both so
        // the host can decide based on its own UI flow.
        onLeaveApp?()
    }
}
