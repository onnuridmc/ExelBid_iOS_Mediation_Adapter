// Compatible with: Kakao AdFit SDK 3.x (adfit-spm)
//
// AdFit's native flow differs from URL-based networks:
// 1. `AdFitNativeAdLoader` issues the request and yields an
//    `AdFitNativeAd` carrying text assets (title/body/profile/CTA).
// 2. AdFit does NOT expose image URLs — the icon and main media render
//    through SDK-owned views. So `normalise(...)` maps only the text
//    assets onto `EBNativeAdModel`, and the media is shown at bind time.
// 3. `bind(view:viewController:)` wraps the host's rendered view in a
//    bridge that adopts `AdFitNativeAdRenderable`, hands AdFit an
//    `AdFitMediaView` for the main media slot, and calls `bind(_:)` so
//    AdFit attaches its own click + impression instrumentation.

import Foundation
import UIKit
import ExelBidSDK

#if canImport(AdFitSDK)
import AdFitSDK

public final class AdFitNativeAdapter: NSObject, EBNativeMediationAdapter {

    public static let networkID = "adfit"
    public static var isAvailable: Bool { true }

    public var onImpression: (() -> Void)?
    public var onImpression50: (() -> Void)?
    public var onImpression100: (() -> Void)?
    public var onClick: (() -> Void)?
    public var onLeaveApp: (() -> Void)?
    public var onClickFinish: (() -> Void)?

    private var loader: AdFitNativeAdLoader?
    private var loaded: AdFitNativeAd?
    private var bridge: AdFitRenderableBridge?
    private var mediaView: AdFitMediaView?
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
                self.startLoad(unitId: unitId, rootViewController: rootViewController)
            }
        }
    }

    private func startLoad(unitId: String, rootViewController: UIViewController?) {
        let loader = AdFitNativeAdLoader(
            clientId: unitId,
            count: 1,
            userObject: nil,
            contentObject: nil
        )
        loader.delegate = self
        loader.rootViewController = rootViewController
        // A loader is single-use: loadAd may be called only once.
        loader.loadAd(keyword: nil, regionId: nil, duplicateKey: nil)
        self.loader = loader
    }

    public func bind(view: UIView, viewController: UIViewController?) {
        guard let ad = loaded else { return }
        Task { @MainActor in
            // AdFit binds against a view adopting `AdFitNativeAdRenderable`.
            // The host's rendered view conforms to `EBNativeAdRendering`
            // instead, so wrap it in a bridge (shared reparent helper keeps
            // the ad exactly where the host positioned it) and map the
            // outlets across. Returns false if the host view isn't on-screen
            // yet — nothing for AdFit to bind or track.
            let bridge = AdFitRenderableBridge(frame: view.frame)
            guard EBNativeAdContainerReparenter.wrap(view, in: bridge) else {
                return
            }

            if let r = view as? EBNativeAdRendering {
                bridge.titleLabel       = r.nativeTitleTextLabel?() ?? nil
                bridge.bodyLabel        = r.nativeMainTextLabel?() ?? nil
                bridge.profileNameLabel = r.nativeSponsoredTextLabel?() ?? nil
                bridge.profileIconView  = r.nativeIconImageView?() ?? nil

                // AdFit renders the main image / video through an
                // `AdFitMediaView`, which the SDK fills into the host's
                // `nativeMediaView()` slot — the single home for the main
                // creative. Without that slot there is no main media asset to
                // show (text/icon-only layout).
                if let slot = r.nativeMediaView?() ?? nil {
                    let media = AdFitMediaView(frame: .zero)
                    media.translatesAutoresizingMaskIntoConstraints = false
                    slot.addSubview(media)
                    NSLayoutConstraint.activate([
                        media.leadingAnchor.constraint(equalTo: slot.leadingAnchor),
                        media.trailingAnchor.constraint(equalTo: slot.trailingAnchor),
                        media.topAnchor.constraint(equalTo: slot.topAnchor),
                        media.bottomAnchor.constraint(equalTo: slot.bottomAnchor),
                    ])
                    bridge.mediaView = media
                    self.mediaView = media
                }
            }

            // Resolve Auto Layout before AdFit measures the asset views.
            (bridge.superview ?? bridge).layoutIfNeeded()

            ad.rootViewController = viewController
            ad.delegate = self
            ad.bind(bridge)
            self.bridge = bridge
        }
    }

    public func unbind() {
        Task { @MainActor in
            self.mediaView?.removeFromSuperview()
            self.mediaView = nil
            self.bridge?.removeFromSuperview()
            self.bridge = nil
        }
    }

    public func cancel() {
        loader?.delegate = nil
        loader = nil
        loaded?.delegate = nil
        loaded = nil
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

    /// Map AdFit's text assets onto v3's `EBNativeAdModel`. AdFit exposes no
    /// image URLs (icon/main render through SDK views at bind time), so only
    /// the text fields are carried here. `EBNativeAdModel` is JSON-decodable,
    /// so we build the equivalent payload and decode through it.
    private func normalise(_ ad: AdFitNativeAd) -> EBNativeAdModel {
        var payload: [String: Any] = [:]
        if let v = ad.title        { payload["title"] = v }
        if let v = ad.body         { payload["desc"]  = v }
        if let v = ad.callToAction { payload["ctatext"] = v }
        if let v = ad.profileName  { payload["sponsored"] = v }
        if let v = ad.displayUrl   { payload["displayurl"] = v }
        let data = (try? JSONSerialization.data(withJSONObject: payload)) ?? Data("{}".utf8)
        return (try? JSONDecoder().decode(EBNativeAdModel.self, from: data))
            ?? (try! JSONDecoder().decode(EBNativeAdModel.self, from: Data("{}".utf8)))
    }
}

extension AdFitNativeAdapter: AdFitNativeAdLoaderDelegate {
    public func nativeAdLoaderDidReceiveAd(_ nativeAd: AdFitNativeAd) {
        self.loaded = nativeAd
        resume(returning: normalise(nativeAd))
    }

    public func nativeAdLoaderDidFailToReceiveAd(
        _ nativeAdLoader: AdFitNativeAdLoader,
        error: Error
    ) {
        resume(throwing: error)
    }
}

extension AdFitNativeAdapter: AdFitNativeAdDelegate {
    // AdFit's native delegate only reports clicks — there is no impression
    // callback, so `onImpression*` are driven by ExelBid's own trackers.
    public func nativeAdDidClickAd(_ nativeAd: AdFitNativeAd) {
        onClick?()
    }
}

/// Bridges the host's `EBNativeAdRendering` outlets to the
/// `AdFitNativeAdRenderable` interface AdFit's `bind(_:)` requires.
final class AdFitRenderableBridge: UIView, AdFitNativeAdRenderable {
    weak var titleLabel: UILabel?
    weak var bodyLabel: UILabel?
    weak var profileNameLabel: UILabel?
    weak var profileIconView: UIImageView?
    weak var ctaButton: UIButton?
    weak var mediaView: AdFitMediaView?

    func adTitleLabel() -> UILabel? { titleLabel }
    func adBodyLabel() -> UILabel? { bodyLabel }
    func adCallToActionButton() -> UIButton? { ctaButton }
    func adProfileNameLabel() -> UILabel? { profileNameLabel }
    func adProfileIconView() -> UIImageView? { profileIconView }
    func adMediaView() -> AdFitMediaView? { mediaView }
}

#else

public final class AdFitNativeAdapter: NSObject, EBNativeMediationAdapter {
    public static let networkID = "adfit"
    public static var isAvailable: Bool { false }

    public var onImpression: (() -> Void)?
    public var onImpression50: (() -> Void)?
    public var onImpression100: (() -> Void)?
    public var onClick: (() -> Void)?
    public var onLeaveApp: (() -> Void)?
    public var onClickFinish: (() -> Void)?

    public override init() { super.init() }

    public func load(unitId: String, desiredAssets: Set<EBNativeAsset>, rootViewController: UIViewController?, timeout: TimeInterval) async throws -> EBNativeAdModel {
        throw AdFitNativeAdapterError.sdkNotLinked
    }
    public func bind(view: UIView, viewController: UIViewController?) {}
    public func unbind() {}
    public func cancel() {}

    enum AdFitNativeAdapterError: Error { case sdkNotLinked }
}

#endif
