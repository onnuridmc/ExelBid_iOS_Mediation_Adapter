// Compatible with: Kakao AdFit SDK 3.x
// Last verified: 2026-05-20
//
// NOTE: AdFit is distributed via CocoaPods. To enable this adapter in a
// SwiftPM-only host, add a binary target for AdFitSDK in the host's
// own Package.swift or use a SwiftPM bridging shim. The implementation
// below is wrapped in `#if canImport(AdFitSDK)` so this file compiles
// even when AdFit is absent — in that case the adapter resolves to
// `isAvailable == false` and is skipped by the orchestrator.

import Foundation
import UIKit
import ExelBidSDK

#if canImport(AdFitSDK)
import AdFitSDK

public final class AdFitBannerAdapter: NSObject, EBBannerMediationAdapter {

    public static let networkID = "adfit"
    public static var isAvailable: Bool { true }

    public var onClick: (() -> Void)?
    public var onLeaveApp: (() -> Void)?
    public var onClickFinish: (() -> Void)?

    private var bannerView: AdFitBannerAdView?
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
                // AdFit takes a string like "320x50" / "300x250" /
                // "320x100". Pick by orchestrator-supplied height.
                let sizeString: String
                switch Int(size.height) {
                case 250...:      sizeString = "300x250"
                case 100...:      sizeString = "320x100"
                default:          sizeString = "320x50"
                }

                let view = AdFitBannerAdView(
                    clientId: unitId,
                    adUnitSize: sizeString
                )
                view.rootViewController = rootViewController
                view.delegate = self
                view.loadAd()
                self.bannerView = view
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

extension AdFitBannerAdapter: AdFitBannerAdViewDelegate {

    public func adFitBannerAdViewDidReceiveAd(_ bannerView: AdFitBannerAdView) {
        resume(returning: bannerView)
    }

    public func adFitBannerAdView(
        _ bannerView: AdFitBannerAdView,
        didFailToReceiveAdWithError error: Error
    ) {
        resume(throwing: error)
    }

    public func adFitBannerAdViewDidClickAd(_ bannerView: AdFitBannerAdView) {
        onClick?()
    }
}

#else

// AdFit SDK not linked. Provide a placeholder so the module compiles;
// `isAvailable` returns false so the orchestrator treats the adapter
// as unregistered.
public final class AdFitBannerAdapter: NSObject, EBBannerMediationAdapter {

    public static let networkID = "adfit"
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
        throw AdFitAdapterError.sdkNotLinked
    }

    public func cancel() {}

    enum AdFitAdapterError: Error {
        case sdkNotLinked
    }
}

#endif
