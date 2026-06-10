// Compatible with: Facebook Audience Network 6.x

import Foundation
import UIKit
import ExelBidSDK

#if canImport(FBAudienceNetwork)
import FBAudienceNetwork

/// Mediation adapter for Facebook Audience Network native ads
/// (`FBNativeAd`).
///
/// FAN's native flow:
/// 1. `FBNativeAd(placementID:)` + `loadAd()` issues the request.
/// 2. `nativeAdDidLoad` yields the populated `FBNativeAd`.
/// 3. Adapter normalises typed assets onto v3's `EBNativeAdModel`.
/// 4. `bind(view:viewController:)` calls
///    `FBNativeAd.registerView(forInteraction:withViewController:)` so
///    FAN attaches its own click + impression instrumentation.
public final class FANNativeAdapter: NSObject, EBNativeMediationAdapter {

    public static let networkID = "fan"
    public static var isAvailable: Bool { true }

    public var onImpression: (() -> Void)?
    public var onImpression50: (() -> Void)?
    public var onImpression100: (() -> Void)?
    public var onClick: (() -> Void)?
    public var onLeaveApp: (() -> Void)?
    public var onClickFinish: (() -> Void)?

    private var nativeAd: FBNativeAd?
    private var mediaView: FBMediaView?
    private var adOptionsView: FBAdOptionsView?
    private var continuation: CheckedContinuation<EBNativeAdModel, Error>?
    private var resumed = false

    public override init() { super.init() }

    public func load(
        unitId: String,
        desiredAssets: Set<EBNativeAsset>,
        options: EBAdOptions,
        rootViewController: UIViewController?,
        timeout: TimeInterval
    ) async throws -> EBNativeAdModel {
        // `options` is honoured by FAN's own request configuration, so
        // it isn't forwarded here.
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<EBNativeAdModel, Error>) in
            self.continuation = cont
            self.resumed = false
            DispatchQueue.main.async {
                let ad = FBNativeAd(placementID: unitId)
                ad.delegate = self
                ad.loadAd()
                self.nativeAd = ad
            }
        }
    }

    public func bind(view: UIView, viewController: UIViewController?) {
        guard let ad = nativeAd else { return }
        Task { @MainActor in
            let r = view as? EBNativeAdRendering

            // FAN renders the main creative through its own `FBMediaView`
            // (there is no addressable media URL), so it *requires* a media
            // view to register. Prefer the host's `nativeMediaView()` slot;
            // if absent, attach a zero-size hidden one so registration still
            // succeeds for click/impression — the media just won't be shown.
            let media = FBMediaView()
            media.translatesAutoresizingMaskIntoConstraints = false
            if let slot = r?.nativeMediaView?() ?? nil {
                slot.addSubview(media)
                NSLayoutConstraint.activate([
                    media.leadingAnchor.constraint(equalTo: slot.leadingAnchor),
                    media.trailingAnchor.constraint(equalTo: slot.trailingAnchor),
                    media.topAnchor.constraint(equalTo: slot.topAnchor),
                    media.bottomAnchor.constraint(equalTo: slot.bottomAnchor),
                ])
            } else {
                media.isHidden = true
                view.addSubview(media)
                NSLayoutConstraint.activate([
                    media.topAnchor.constraint(equalTo: view.topAnchor),
                    media.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    media.widthAnchor.constraint(equalToConstant: 0),
                    media.heightAnchor.constraint(equalToConstant: 0),
                ])
            }
            self.mediaView = media

            // FAN's AdChoices/ad-options overlay (policy-required). Rendered
            // into the host's slot when provided.
            if let slot = r?.nativeAdChoicesView?() ?? nil {
                let options = FBAdOptionsView()
                options.nativeAd = ad
                options.translatesAutoresizingMaskIntoConstraints = false
                slot.addSubview(options)
                NSLayoutConstraint.activate([
                    options.leadingAnchor.constraint(equalTo: slot.leadingAnchor),
                    options.trailingAnchor.constraint(equalTo: slot.trailingAnchor),
                    options.topAnchor.constraint(equalTo: slot.topAnchor),
                    options.bottomAnchor.constraint(equalTo: slot.bottomAnchor),
                ])
                self.adOptionsView = options
            }

            // FAN provides no icon URL — the SDK loads the icon into a view we
            // register. Hand it the host's icon image view when available.
            let iconImageView = r?.nativeIconImageView?() ?? nil

            // Clickable views drive the tap-through (CTA + main media). The
            // main creative is FAN's own `FBMediaView` in `nativeMediaView()`.
            var clickable: [UIView] = [media]
            if let cta = r?.nativeCallToActionButton?() ?? nil { clickable.append(cta) }

            ad.registerView(
                forInteraction: view,
                mediaView: media,
                iconImageView: iconImageView,
                viewController: viewController,
                clickableViews: clickable.isEmpty ? nil : clickable
            )
        }
    }

    public func unbind() {
        nativeAd?.unregisterView()
        mediaView?.removeFromSuperview()
        mediaView = nil
        adOptionsView?.removeFromSuperview()
        adOptionsView = nil
    }

    public func cancel() {
        nativeAd?.delegate = nil
        nativeAd = nil
        resume(throwing: CancellationError())
    }

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

    private func normalise(_ ad: FBNativeAd) -> EBNativeAdModel {
        var payload: [String: Any] = [:]
        if let v = ad.advertiserName       { payload["title"] = v }
        if let v = ad.bodyText             { payload["desc"]  = v }
        if let v = ad.callToAction         { payload["ctatext"] = v }
        if let v = ad.sponsoredTranslation { payload["sponsored"] = v }
        // FAN exposes no addressable icon/cover URLs — the icon and main
        // media render through views registered at bind time (icon image
        // view + `FBMediaView`), so only text assets are carried here.
        let data = (try? JSONSerialization.data(withJSONObject: payload)) ?? Data("{}".utf8)
        return (try? JSONDecoder().decode(EBNativeAdModel.self, from: data))
            ?? (try! JSONDecoder().decode(EBNativeAdModel.self, from: Data("{}".utf8)))
    }
}

extension FANNativeAdapter: FBNativeAdDelegate {
    public func nativeAdDidLoad(_ nativeAd: FBNativeAd) {
        resume(returning: normalise(nativeAd))
    }
    public func nativeAd(_ nativeAd: FBNativeAd, didFailWithError error: Error) {
        resume(throwing: error)
    }
    public func nativeAdDidClick(_ nativeAd: FBNativeAd) {
        onClick?()
    }
    public func nativeAdWillLogImpression(_ nativeAd: FBNativeAd) {
        onImpression?()
    }
    public func nativeAdDidFinishHandlingClick(_ nativeAd: FBNativeAd) {
        onClickFinish?()
    }
}

#else

public final class FANNativeAdapter: NSObject, EBNativeMediationAdapter {
    public static let networkID = "fan"
    public static var isAvailable: Bool { false }

    public var onImpression: (() -> Void)?
    public var onImpression50: (() -> Void)?
    public var onImpression100: (() -> Void)?
    public var onClick: (() -> Void)?
    public var onLeaveApp: (() -> Void)?
    public var onClickFinish: (() -> Void)?

    public override init() { super.init() }

    public func load(unitId: String, desiredAssets: Set<EBNativeAsset>, options: EBAdOptions, rootViewController: UIViewController?, timeout: TimeInterval) async throws -> EBNativeAdModel {
        throw FANNativeAdapterError.sdkNotLinked
    }
    public func bind(view: UIView, viewController: UIViewController?) {}
    public func unbind() {}
    public func cancel() {}

    enum FANNativeAdapterError: Error { case sdkNotLinked }
}

#endif
