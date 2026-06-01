// Compatible with: Facebook Audience Network 16.x
// Last verified: 2026-05-21

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
/// 3. Adapter normalises typed assets onto v3's `NativeAdModel`.
/// 4. `bind(view:viewController:)` calls
///    `FBNativeAd.registerView(forInteraction:withViewController:)` so
///    FAN attaches its own click + impression instrumentation.
public final class FANNativeAdapter: NSObject, NativeMediationAdapter {

    public static let networkID = "fan"
    public static var isAvailable: Bool { true }

    public var onImpression: (() -> Void)?
    public var onImpression50: (() -> Void)?
    public var onImpression100: (() -> Void)?
    public var onClick: (() -> Void)?
    public var onLeaveApp: (() -> Void)?
    public var onClickFinish: (() -> Void)?

    private var nativeAd: FBNativeAd?
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
                let ad = FBNativeAd(placementID: unitId)
                ad.delegate = self
                ad.loadAd()
                self.nativeAd = ad
            }
        }
    }

    public func bind(view: UIView, viewController: UIViewController?) {
        guard let ad = nativeAd, let vc = viewController else { return }
        Task { @MainActor in
            ad.registerView(forInteraction: view, with: vc)
        }
    }

    public func unbind() {
        nativeAd?.unregisterView()
    }

    public func cancel() {
        nativeAd?.delegate = nil
        nativeAd = nil
        resume(throwing: CancellationError())
    }

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

    private func normalise(_ ad: FBNativeAd) -> NativeAdModel {
        var payload: [String: Any] = [:]
        if let v = ad.advertiserName       { payload["title"] = v }
        if let v = ad.bodyText             { payload["desc"]  = v }
        if let v = ad.callToAction         { payload["ctatext"] = v }
        if let v = ad.sponsoredTranslation { payload["sponsored"] = v }
        if let v = ad.iconImage?.url?.absoluteString { payload["icon"] = v }
        if let v = ad.coverImage?.url?.absoluteString { payload["main"] = v }
        let data = (try? JSONSerialization.data(withJSONObject: payload)) ?? Data("{}".utf8)
        return (try? JSONDecoder().decode(NativeAdModel.self, from: data))
            ?? (try! JSONDecoder().decode(NativeAdModel.self, from: Data("{}".utf8)))
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
    public func nativeAdDidLogImpression(_ nativeAd: FBNativeAd) {
        onImpression?()
    }
    public func nativeAdDidFinishHandlingClick(_ nativeAd: FBNativeAd) {
        onClickFinish?()
    }
}

#else

public final class FANNativeAdapter: NSObject, NativeMediationAdapter {
    public static let networkID = "fan"
    public static var isAvailable: Bool { false }

    public var onImpression: (() -> Void)?
    public var onImpression50: (() -> Void)?
    public var onImpression100: (() -> Void)?
    public var onClick: (() -> Void)?
    public var onLeaveApp: (() -> Void)?
    public var onClickFinish: (() -> Void)?

    public override init() { super.init() }

    public func load(unitId: String, desiredAssets: Set<NativeAsset>, rootViewController: UIViewController?, timeout: TimeInterval) async throws -> NativeAdModel {
        throw FANNativeAdapterError.sdkNotLinked
    }
    public func bind(view: UIView, viewController: UIViewController?) {}
    public func unbind() {}
    public func cancel() {}

    enum FANNativeAdapterError: Error { case sdkNotLinked }
}

#endif
