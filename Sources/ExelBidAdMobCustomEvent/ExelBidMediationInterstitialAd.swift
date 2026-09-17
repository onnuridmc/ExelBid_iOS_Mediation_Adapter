// Compatible with: Google Mobile Ads SDK 12.x / 13.x

import Foundation
import UIKit
import ExelBidSDK
import GoogleMobileAds

/// A loaded ExelBid interstitial handed to the Google Mobile Ads SDK.
///
/// Unlike the banner, this format needs no changes in the ExelBid SDK:
/// `EBInterstitialAd.onLoad` fires when the server response is decoded, not
/// when a creative renders, so the completion handler can run while the ad is
/// still offscreen — exactly what GMA expects.
///
/// Both SDKs treat the format as single-use: `EBInterstitialAd` clears its
/// loaded response on dismissal, and GMA discards the ad object after one
/// presentation.
final class ExelBidMediationInterstitialAd: NSObject, MediationInterstitialAd {

    // MARK: - State

    private let interstitial: EBInterstitialAd
    private var completionHandler: GADMediationInterstitialLoadCompletionHandler?
    private var eventDelegate: MediationInterstitialAdEventDelegate?
    /// Keeps the instance alive between `load()` and the completion handler.
    private var selfRetain: ExelBidMediationInterstitialAd?

    // MARK: - Init

    init(adUnitId: String, options: EBAdOptions) {
        interstitial = EBInterstitialAd(adUnitId: adUnitId)
        interstitial.options = options
        super.init()
    }

    // MARK: - Loading

    func load(completionHandler: @escaping GADMediationInterstitialLoadCompletionHandler) {
        self.completionHandler = completionHandler
        self.selfRetain = self

        interstitial.onLoad = { [weak self] in
            self?.finishLoading(with: nil)
        }
        interstitial.onFail = { [weak self] error in
            guard let self = self else { return }
            if self.completionHandler != nil {
                // Still loading — hand the error back so the waterfall moves on.
                self.finishLoading(with: error.asNSError)
            } else {
                // Already loaded; this is a `.notReady` from present(from:).
                self.eventDelegate?.didFailToPresentWithError(error.asNSError)
            }
        }
        interstitial.onWillAppear = { [weak self] in
            self?.eventDelegate?.willPresentFullScreenView()
        }
        interstitial.onDidAppear = { [weak self] in
            // The creative is on screen — the same moment the SDK counts the
            // impression server-side.
            self?.eventDelegate?.reportImpression()
        }
        interstitial.onClick = { [weak self] in
            self?.eventDelegate?.reportClick()
        }
        interstitial.onWillDisappear = { [weak self] in
            self?.eventDelegate?.willDismissFullScreenView()
        }
        interstitial.onDidDisappear = { [weak self] in
            self?.eventDelegate?.didDismissFullScreenView()
        }
        // `onLeaveApp` / `onClickFinish` have no counterpart in
        // MediationAdEventDelegate and are intentionally not forwarded.

        interstitial.load()
    }

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

    func cancel() {
        interstitial.stop()
        completionHandler = nil
        selfRetain = nil
    }

    // MARK: - MediationInterstitialAd

    /// GMA calls this on the main thread.
    func present(from viewController: UIViewController) {
        MainActor.assumeIsolated {
            interstitial.present(from: viewController)
        }
    }
}
