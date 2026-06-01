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
/// 3. The adapter normalises those assets onto v3's `NativeAdModel`
///    and returns it from `load(...)`.
/// 4. The orchestrator/façade renders the model into the host's view.
/// 5. `bind(view:viewController:)` registers the rendered view with
///    AdMob via `NativeAdView.nativeAd = ...` so AdMob can attach
///    its own click + impression instrumentation.
public final class AdMobNativeAdapter: NSObject, NativeMediationAdapter {

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
    private var continuation: CheckedContinuation<NativeAdModel, Error>?
    private var resumed = false

    public override init() { super.init() }

    public func load(
        unitId: String,
        desiredAssets: Set<NativeAsset>,
        rootViewController: UIViewController?,
        timeout: TimeInterval
    ) async throws -> NativeAdModel {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<NativeAdModel, Error>) in
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
            // AdMob requires its own NativeAdView superview to drive
            // click + impression tracking. Wrap the host's rendered
            // view in a NativeAdView and have AdMob own the
            // instrumentation.
            let wrapper = NativeAdView(frame: view.bounds)
            wrapper.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.translatesAutoresizingMaskIntoConstraints = false
            wrapper.addSubview(view)
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
                view.topAnchor.constraint(equalTo: wrapper.topAnchor),
                view.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
            ])
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

    private func resume(returning model: NativeAdModel) {
        guard !resumed else { return }
        resumed = true
        continuation?.resume(returning: model); continuation = nil
    }

    private func resume(throwing error: Error) {
        guard !resumed else { return }
        resumed = true
        continuation?.resume(throwing: error); continuation = nil
    }

    /// Normalise AdMob's typed assets onto v3's `NativeAdModel` shape.
    /// `NativeAdModel` is JSON-decodable — we build a small JSON
    /// payload that mirrors what the ExelBid server would have
    /// returned for the equivalent assets and decode through that.
    private func normalise(_ ad: GoogleMobileAds.NativeAd) -> NativeAdModel {
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
        return (try? JSONDecoder().decode(NativeAdModel.self, from: data))
            ?? (try! JSONDecoder().decode(NativeAdModel.self, from: Data("{}".utf8)))
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
