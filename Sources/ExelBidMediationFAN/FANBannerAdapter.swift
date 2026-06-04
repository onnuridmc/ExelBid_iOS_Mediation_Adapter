// Compatible with: Facebook Audience Network 16.x
//
// NOTE: FAN is distributed via CocoaPods only — Meta's `facebook-ios-sdk`
// SwiftPM package does NOT include the Audience Network module. To
// enable this adapter, the host must link `FBAudienceNetwork` itself
// (CocoaPods, Carthage, or a manual binary target in the host's own
// Package.swift). The implementation is wrapped in
// `#if canImport(FBAudienceNetwork)` so this file compiles in
// SwiftPM-only environments without FAN — in that case the adapter
// resolves to `isAvailable == false` and is skipped by the orchestrator.

import Foundation
import UIKit
import ExelBidSDK

#if canImport(FBAudienceNetwork)
import FBAudienceNetwork

/// Mediation adapter for Facebook Audience Network banners.
///
/// FAN requires a `rootViewController` at init time. If the orchestrator
/// can't supply one (no window yet), the adapter throws — FAN will not
/// render without a view controller to host click flow.
public final class FANBannerAdapter: NSObject, EBBannerMediationAdapter {

    public static let networkID = "fan"
    public static var isAvailable: Bool { true }

    public var onClick: (() -> Void)?
    public var onLeaveApp: (() -> Void)?
    public var onClickFinish: (() -> Void)?

    private var adView: FBAdView?
    private var continuation: CheckedContinuation<UIView, Error>?
    private var resumed = false

    public override init() { super.init() }

    public func load(
        unitId: String,
        size: CGSize,
        rootViewController: UIViewController?,
        timeout: TimeInterval
    ) async throws -> UIView {
        guard let host = rootViewController else {
            throw AdapterError.missingRootViewController
        }

        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            self.resumed = false

            DispatchQueue.main.async {
                // Choose closest FAN size. FAN exposes a small set of
                // fixed sizes; orchestrator's `size` is mostly a hint.
                let fbSize: FBAdSize
                if size.height >= 250 {
                    fbSize = kFBAdSizeHeight250Rectangle
                } else if size.height >= 90 {
                    fbSize = kFBAdSizeHeight90Banner
                } else {
                    fbSize = kFBAdSizeHeight50Banner
                }

                let view = FBAdView(
                    placementID: unitId,
                    adSize: fbSize,
                    rootViewController: host
                )
                view.delegate = self
                view.loadAd()
                self.adView = view
            }
        }
    }

    public func cancel() {
        adView?.delegate = nil
        adView = nil
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

    enum AdapterError: Error {
        case missingRootViewController
    }
}

extension FANBannerAdapter: FBAdViewDelegate {

    public func adViewDidLoad(_ adView: FBAdView) {
        resume(returning: adView)
    }

    public func adView(_ adView: FBAdView, didFailWithError error: Error) {
        resume(throwing: error)
    }

    public func adViewDidClick(_ adView: FBAdView) {
        onClick?()
    }

    public func adViewWillLogImpression(_ adView: FBAdView) {
        // No-op for v3 mediation; orchestrator doesn't expose
        // impression events on the banner protocol (impression is
        // fired by the third-party SDK itself once rendered).
    }

    public func adViewDidFinishHandlingClick(_ adView: FBAdView) {
        onClickFinish?()
    }
}

#else

// FAN SDK not linked. Provide a placeholder so the module compiles;
// `isAvailable` returns false so the orchestrator treats the adapter
// as unregistered.
public final class FANBannerAdapter: NSObject, EBBannerMediationAdapter {

    public static let networkID = "fan"
    public static var isAvailable: Bool { false }

    public var onClick: (() -> Void)?
    public var onLeaveApp: (() -> Void)?
    public var onClickFinish: (() -> Void)?

    public override init() { super.init() }

    public func load(
        unitId: String,
        size: CGSize,
        rootViewController: UIViewController?,
        timeout: TimeInterval
    ) async throws -> UIView {
        throw FANAdapterError.sdkNotLinked
    }

    public func cancel() {}

    enum FANAdapterError: Error {
        case sdkNotLinked
    }
}

#endif
