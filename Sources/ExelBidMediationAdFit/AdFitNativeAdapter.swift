// Compatible with: Kakao AdFit SDK 3.x
// Last verified: 2026-05-21

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

    private var nativeAd: AdFitNativeAdLoader?
    private var loaded: AdFitNativeAd?
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
                let loader = AdFitNativeAdLoader(clientId: unitId)
                loader.delegate = self
                loader.loadAd()
                self.nativeAd = loader
            }
        }
    }

    public func bind(view: UIView, viewController: UIViewController?) {
        guard let ad = loaded else { return }
        Task { @MainActor in
            ad.register(view: view)
        }
    }

    public func unbind() {
        loaded?.unregisterView()
    }

    public func cancel() {
        nativeAd?.delegate = nil
        nativeAd = nil
        loaded = nil
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

    private func normalise(_ ad: AdFitNativeAd) -> EBNativeAdModel {
        var payload: [String: Any] = [:]
        if let v = ad.title       { payload["title"] = v }
        if let v = ad.body        { payload["desc"]  = v }
        if let v = ad.callToAction { payload["ctatext"] = v }
        if let v = ad.profileName  { payload["sponsored"] = v }
        if let v = ad.iconImageURL?.absoluteString { payload["icon"] = v }
        if let v = ad.mainImageURL?.absoluteString { payload["main"] = v }
        let data = (try? JSONSerialization.data(withJSONObject: payload)) ?? Data("{}".utf8)
        return (try? JSONDecoder().decode(EBNativeAdModel.self, from: data))
            ?? (try! JSONDecoder().decode(EBNativeAdModel.self, from: Data("{}".utf8)))
    }
}

extension AdFitNativeAdapter: AdFitNativeAdLoaderDelegate {
    public func adFitNativeAdLoader(
        _ loader: AdFitNativeAdLoader,
        didReceive nativeAd: AdFitNativeAd
    ) {
        self.loaded = nativeAd
        nativeAd.delegate = self
        resume(returning: normalise(nativeAd))
    }
    public func adFitNativeAdLoader(
        _ loader: AdFitNativeAdLoader,
        didFailToReceiveAdWithError error: Error
    ) {
        resume(throwing: error)
    }
}

extension AdFitNativeAdapter: AdFitNativeAdDelegate {
    public func adFitNativeAdDidLogImpression(_ nativeAd: AdFitNativeAd) {
        onImpression?()
    }
    public func adFitNativeAdDidClick(_ nativeAd: AdFitNativeAd) {
        onClick?()
    }
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
