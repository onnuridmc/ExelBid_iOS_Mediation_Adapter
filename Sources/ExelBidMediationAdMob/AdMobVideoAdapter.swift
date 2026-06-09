// Compatible with: Google Mobile Ads SDK 12.x
//
// For non-ExelBid networks, v3's mediation "video" format means a
// FULLSCREEN INTERSTITIAL VIDEO (전면 비디오) — NOT a rewarded ad. This
// adapter is the video-format twin of `AdMobInterstitialAdapter`: both wrap
// the shared `AdMobFullScreenAd` (`InterstitialAd`), which serves either a
// display or video creative through the same fullscreen surface. AdMob
// exposes no quartile callbacks, so `onProgress` is approximated — 0 at
// present, 100 on dismissal (treated as end-of-playback).

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

    private let ad = AdMobFullScreenAd()

    public override init() {
        super.init()
        ad.onWillAppear    = { [weak self] in self?.onWillAppear?() }
        ad.onDidAppear     = { [weak self] in self?.onDidAppear?() }
        ad.onWillDisappear = { [weak self] in self?.onWillDisappear?() }
        ad.onDidDisappear  = { [weak self] in
            // No quartile / complete callback for fullscreen ads; treat
            // dismissal as end-of-playback. (A display creative reports 100
            // on dismiss too, which the host's quartile aggregation tolerates.)
            self?.onProgress?(100)
            self?.onDidDisappear?()
        }
        ad.onClick         = { [weak self] in self?.onClick?(); self?.onLeaveApp?() }
    }

    public func load(
        unitId: String,
        options: EBAdOptions,
        rootViewController: UIViewController?,
        timeout: TimeInterval
    ) async throws {
        // `options` (skip policy etc.) is driven by AdMob's own fullscreen
        // playback UI, so it isn't forwarded here.
        try await ad.load(unitId: unitId)
    }

    @MainActor
    public func present(from viewController: UIViewController) {
        ad.present(from: viewController)
        onProgress?(0)
    }

    public func cancel() {
        ad.cancel()
    }
}
