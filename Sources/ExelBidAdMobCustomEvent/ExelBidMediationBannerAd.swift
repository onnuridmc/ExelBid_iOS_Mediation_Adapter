// Compatible with: Google Mobile Ads SDK 12.x / 13.x

import Foundation
import UIKit
import ExelBidSDK
import GoogleMobileAds

/// A loaded ExelBid banner handed to the Google Mobile Ads SDK.
///
/// Lifecycle contract imposed by GMA:
/// - `completionHandler` must be called exactly once, on the main thread.
/// - Its return value is the event delegate; every impression / click report
///   afterwards goes through it.
/// - GMA releases the adapter once loading finishes, so this object owns the
///   `EBBannerAd` and keeps itself alive until the handler has been called.
final class ExelBidMediationBannerAd: NSObject, MediationBannerAd {

    // MARK: - MediationBannerAd

    /// The view GMA inserts into its `BannerView` hierarchy.
    var view: UIView { banner }

    // MARK: - State

    private let banner: EBBannerAd
    private var completionHandler: GADMediationBannerLoadCompletionHandler?
    private var eventDelegate: MediationBannerAdEventDelegate?
    /// Keeps the instance alive between `load()` and the completion handler.
    private var selfRetain: ExelBidMediationBannerAd?

    // MARK: - Init

    @MainActor
    init(adUnitId: String, adSize: CGSize, options: EBAdOptions) {
        banner = EBBannerAd(adUnitId: adUnitId, size: adSize)
        banner.options = options
        // AdMob owns the refresh cycle for its own slot; leaving ExelBid's
        // RefreshScheduler on would reload the creative behind GMA's back.
        banner.autoRefresh = false
        super.init()
    }

    // MARK: - Loading

    @MainActor
    func load(completionHandler: @escaping GADMediationBannerLoadCompletionHandler) {
        self.completionHandler = completionHandler
        self.selfRetain = self

        // Load-completion signal: `onLoad` fires from BannerWebView's
        // WKNavigationDelegate didFinish, after the creative has loaded. GMA
        // inserts the view only after the completion handler runs, so the
        // banner is still outside any view hierarchy here. That is fine: in a
        // foreground app a detached WKWebView completes navigation normally
        // (verified in a simulator app — onLoad in ~1.3–4.5s with window == nil).
        // Note that a non-hosted SwiftPM XCTest process cannot reproduce this;
        // WebKit never starts navigating there, attached or not.
        banner.onLoad = { [weak self] in
            self?.finishLoading(with: nil)
            // Same call site where the SDK dispatches its own impression
            // trackers, so both counts land in the same cycle.
            self?.eventDelegate?.reportImpression()
        }
        banner.onFail = { [weak self] error in
            self?.finishLoading(with: error.asNSError)
        }
        banner.onClick = { [weak self] in
            self?.eventDelegate?.reportClick()
        }
        // `onLeaveApp` / `onClickFinish` have no counterpart in
        // MediationAdEventDelegate and are intentionally not forwarded.

        banner.load()
    }

    @MainActor
    private func finishLoading(with error: NSError?) {
        guard let handler = completionHandler else { return }
        completionHandler = nil
        defer { selfRetain = nil }

        if let error = error {
            _ = handler(nil, error)
        } else {
            eventDelegate = handler(self, nil)
        }
    }

    @MainActor
    func cancel() {
        banner.stop()
        completionHandler = nil
        selfRetain = nil
    }
}
