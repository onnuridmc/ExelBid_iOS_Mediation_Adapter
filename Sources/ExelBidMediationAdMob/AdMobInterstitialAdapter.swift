// Compatible with: Google Mobile Ads SDK 12.x

import Foundation
import UIKit
import ExelBidSDK
import GoogleMobileAds

/// Mediation adapter for Google AdMob fullscreen interstitials.
///
/// A fullscreen slot can serve a display (image / banner) or video
/// creative; both are driven by the shared `AdMobFullScreenAd`
/// (`InterstitialAd`). This adapter adds only the interstitial-format
/// callback surface — see `AdMobVideoAdapter` for the video-format twin.
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

    private let ad = AdMobFullScreenAd()

    public override init() {
        super.init()
        ad.onWillAppear    = { [weak self] in self?.onWillAppear?() }
        ad.onDidAppear     = { [weak self] in self?.onDidAppear?() }
        ad.onWillDisappear = { [weak self] in self?.onWillDisappear?() }
        ad.onDidDisappear  = { [weak self] in self?.onDidDisappear?() }
        // AdMob does not distinguish click from leave-app; fire both so the
        // host can decide based on its own UI flow.
        ad.onClick         = { [weak self] in self?.onClick?(); self?.onLeaveApp?() }
    }

    public func load(
        unitId: String,
        options: EBAdOptions,
        rootViewController: UIViewController?,
        timeout: TimeInterval
    ) async throws {
        // `options` is honoured by AdMob's own request configuration, so
        // it isn't forwarded here.
        try await ad.load(unitId: unitId)
    }

    @MainActor
    public func present(from viewController: UIViewController) {
        ad.present(from: viewController)
    }

    public func cancel() {
        ad.cancel()
    }
}
