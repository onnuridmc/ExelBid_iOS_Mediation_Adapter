// Compatible with: Google Mobile Ads SDK 12.x
// Last verified: 2026-05-21

import Foundation
import UIKit
import ExelBidSDK
import GoogleMobileAds

/// Mediation adapter for Google AdMob native ads (`NativeAd`).
///
/// AdMob's native flow:
/// 1. `AdLoader` issues the request.
/// 2. The `nativeAdLoader(_:didReceive:)` delegate yields a
///    `GoogleMobileAds.NativeAd` object containing typed assets.
/// 3. The adapter normalises those assets onto v3's `EBNativeAdModel`
///    and returns it from `load(...)`.
/// 4. The orchestrator/façade renders the model into the host's view.
/// 5. `bind(view:viewController:)` registers the rendered view with
///    AdMob via `NativeAdView.nativeAd = ...` so AdMob can attach
///    its own click + impression instrumentation.
public final class AdMobNativeAdapter: NSObject, EBNativeMediationAdapter {

    public static let networkID = "admob"
    public static var isAvailable: Bool { true }

    public var onImpression: (() -> Void)?
    public var onImpression50: (() -> Void)?
    public var onImpression100: (() -> Void)?
    public var onClick: (() -> Void)?
    public var onLeaveApp: (() -> Void)?
    public var onClickFinish: (() -> Void)?

    private var loader: AdLoader?
    private var nativeAd: GoogleMobileAds.NativeAd?
    private var nativeAdView: NativeAdView?
    private var continuation: CheckedContinuation<EBNativeAdModel, Error>?
    private var resumed = false

    public override init() { super.init() }

    public func load(
        unitId: String,
        desiredAssets: Set<EBNativeAsset>,
        rootViewController: UIViewController?,
        timeout: TimeInterval
    ) async throws -> EBNativeAdModel {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<EBNativeAdModel, Error>) in
            self.continuation = cont
            self.resumed = false

            DispatchQueue.main.async {
                let loader = AdLoader(
                    adUnitID: unitId,
                    rootViewController: rootViewController,
                    adTypes: [.native],
                    options: nil
                )
                loader.delegate = self
                loader.load(Request())
                self.loader = loader
            }
        }
    }

    public func bind(view: UIView, viewController: UIViewController?) {
        guard let nativeAd = nativeAd else { return }
        Task { @MainActor in
            // AdMob requires its asset views to live inside a `NativeAdView`
            // subtree to drive click + impression tracking. Slot one into the
            // host view's place in the hierarchy and reparent the rendered
            // creative inside it (shared helper), so the ad stays exactly
            // where the host positioned it. Returns false if the host view
            // isn't on-screen yet — nothing for AdMob to wrap or track.
            let wrapper = NativeAdView(frame: view.frame)
            guard EBNativeAdContainerReparenter.wrap(view, in: wrapper) else {
                return
            }

            // Map AdMob's asset outlets onto the host's rendered subviews
            // (exposed via `EBNativeAdRendering`). AdMob only makes the views
            // it has *registered* clickable/trackable — without at least
            // `callToActionView` wired, taps are never reported, the ad is
            // effectively non-clickable, and it violates AdMob's native
            // policy. The subviews are already in `wrapper`'s subtree (they
            // live inside `view`), which AdMob requires for registration.
            if let r = view as? EBNativeAdRendering {
                wrapper.headlineView     = r.nativeTitleTextLabel?() ?? nil
                wrapper.bodyView         = r.nativeMainTextLabel?() ?? nil
                wrapper.callToActionView = r.nativeCallToActionTextLabel?() ?? nil
                wrapper.advertiserView   = r.nativeSponsoredTextLabel?() ?? nil
                wrapper.storeView        = r.nativeDisplayURLTextLabel?() ?? nil
                wrapper.iconView         = r.nativeIconImageView?() ?? nil

                if let slot = r.nativeMediaView?() ?? nil {
                    // Network-owned media: host a `MediaView` in the host's
                    // media slot and let AdMob render the creative there
                    // (supports video). The SDK skipped the static main image
                    // because this slot is present.
                    let mediaView = MediaView()
                    mediaView.translatesAutoresizingMaskIntoConstraints = false
                    slot.addSubview(mediaView)
                    NSLayoutConstraint.activate([
                        mediaView.leadingAnchor.constraint(equalTo: slot.leadingAnchor),
                        mediaView.trailingAnchor.constraint(equalTo: slot.trailingAnchor),
                        mediaView.topAnchor.constraint(equalTo: slot.topAnchor),
                        mediaView.bottomAnchor.constraint(equalTo: slot.bottomAnchor),
                    ])
                    mediaView.mediaContent = nativeAd.mediaContent
                    wrapper.mediaView = mediaView
                } else {
                    // No media slot — register the SDK-rendered static main
                    // image (URL-loaded by `StaticNativeRenderer`) instead.
                    wrapper.imageView = r.nativeMainImageView?() ?? nil
                }
            }
            // AdChoices is rendered automatically into a corner of the
            // `NativeAdView`, so no `nativeAdChoicesView()` slot is needed.

            // Assign `nativeAd` last, per AdMob's documented order, so the
            // registered outlets are all in place before instrumentation
            // attaches.
            wrapper.nativeAd = nativeAd
            self.nativeAdView = wrapper
        }
    }

    public func unbind() {
        Task { @MainActor in
            self.nativeAdView?.removeFromSuperview()
            self.nativeAdView = nil
        }
    }

    public func cancel() {
        loader = nil
        nativeAd = nil
        resume(throwing: CancellationError())
    }

    // MARK: - Helpers

    private func resume(returning model: EBNativeAdModel) {
        guard !resumed else { return }
        resumed = true
        continuation?.resume(returning: model); continuation = nil
    }

    private func resume(throwing error: Error) {
        guard !resumed else { return }
        resumed = true
        continuation?.resume(throwing: error); continuation = nil
    }

    /// Normalise AdMob's typed assets onto v3's `EBNativeAdModel` shape.
    /// `EBNativeAdModel` is JSON-decodable — we build a small JSON
    /// payload that mirrors what the ExelBid server would have
    /// returned for the equivalent assets and decode through that.
    private func normalise(_ ad: GoogleMobileAds.NativeAd) -> EBNativeAdModel {
        var payload: [String: Any] = [:]
        if let v = ad.headline       { payload["title"] = v }
        if let v = ad.body           { payload["desc"]  = v }
        if let v = ad.callToAction   { payload["ctatext"] = v }
        if let v = ad.advertiser     { payload["sponsored"] = v }
        if let v = ad.price          { payload["price"] = v }
        if let v = ad.store          { payload["displayurl"] = v }
        if let s = ad.starRating?.stringValue { payload["rating"] = s }
        if let v = ad.icon?.imageURL?.absoluteString { payload["icon"] = v }
        if let imgs = ad.images, let v = imgs.first?.imageURL?.absoluteString {
            payload["main"] = v
        }
        let data = (try? JSONSerialization.data(withJSONObject: payload)) ?? Data("{}".utf8)
        return (try? JSONDecoder().decode(EBNativeAdModel.self, from: data))
            ?? (try! JSONDecoder().decode(EBNativeAdModel.self, from: Data("{}".utf8)))
    }
}

extension AdMobNativeAdapter: NativeAdLoaderDelegate {
    public func adLoader(_ adLoader: AdLoader, didReceive nativeAd: GoogleMobileAds.NativeAd) {
        self.nativeAd = nativeAd
        nativeAd.delegate = self
        resume(returning: normalise(nativeAd))
    }

    public func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        resume(throwing: error)
    }
}

extension AdMobNativeAdapter: NativeAdDelegate {
    public func nativeAdDidRecordImpression(_ nativeAd: GoogleMobileAds.NativeAd) {
        onImpression?()
    }
    public func nativeAdDidRecordClick(_ nativeAd: GoogleMobileAds.NativeAd) {
        onClick?()
    }
    public func nativeAdWillLeaveApplication(_ nativeAd: GoogleMobileAds.NativeAd) {
        onLeaveApp?()
    }
    public func nativeAdDidDismissScreen(_ nativeAd: GoogleMobileAds.NativeAd) {
        onClickFinish?()
    }
}
