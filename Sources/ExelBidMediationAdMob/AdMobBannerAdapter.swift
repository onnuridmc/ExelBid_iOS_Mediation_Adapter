// Compatible with: Google Mobile Ads SDK 11.x / 12.x

import Foundation
import UIKit
import ExelBidSDK
import GoogleMobileAds

/// Mediation adapter for Google AdMob banners.
///
/// Bridge layer:
/// - Translates `EBBannerMediationAdapter.load(...)` → `BannerView` + delegate.
/// - Maps AdMob delegate callbacks (`bannerViewDidReceiveAd`,
///   `bannerView(_:didFailToReceiveAdWithError:)`,
///   `bannerViewDidRecordClick`, `bannerViewWillLeaveApplication`)
///   to the closure callbacks the orchestrator expects.
public final class AdMobBannerAdapter: NSObject, EBBannerMediationAdapter {

    public static let networkID = "admob"
    public static var isAvailable: Bool { true }

    public var onClick: (() -> Void)?
    public var onLeaveApp: (() -> Void)?
    public var onClickFinish: (() -> Void)?

    private var bannerView: BannerView?
    private var continuation: CheckedContinuation<UIView, Error>?
    private var resumed = false

    public override init() { super.init() }

    public func load(
        unitId: String,
        size: CGSize,
        rootViewController: UIViewController?,
        timeout: TimeInterval
    ) async throws -> UIView {
        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            self.resumed = false

            DispatchQueue.main.async {
                // Prefer adaptive size for the given width; fall back to
                // an absolute size if the host's container can't yield
                // a useful width (e.g. zero-sized parent).
                let adSize: AdSize
                if size.width >= 320 {
                    adSize = currentOrientationAnchoredAdaptiveBanner(width: size.width)
                } else {
                    adSize = AdSizeBanner
                }

                let banner = BannerView(adSize: adSize)
                banner.adUnitID = unitId
                banner.rootViewController = rootViewController
                banner.delegate = self
                banner.load(Request())
                self.bannerView = banner
            }
        }
    }

    public func cancel() {
        bannerView?.delegate = nil
        bannerView = nil
        resume(throwing: CancellationError())
    }

    private func resume(returning view: UIView) {
        guard !resumed else { return }
        resumed = true
        continuation?.resume(returning: view)
        continuation = nil
    }

    private func resume(throwing error: Error) {
        guard !resumed else { return }
        resumed = true
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

extension AdMobBannerAdapter: BannerViewDelegate {

    public func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        resume(returning: bannerView)
    }

    public func bannerView(
        _ bannerView: BannerView,
        didFailToReceiveAdWithError error: Error
    ) {
        resume(throwing: error)
    }

    public func bannerViewDidRecordClick(_ bannerView: BannerView) {
        onClick?()
    }

    public func bannerViewWillLeaveApplication(_ bannerView: BannerView) {
        onLeaveApp?()
    }

    public func bannerViewDidDismissScreen(_ bannerView: BannerView) {
        // User returned to the host app after tapping out (in-app
        // overlay dismissed). Treat as "click flow finished".
        onClickFinish?()
    }
}
