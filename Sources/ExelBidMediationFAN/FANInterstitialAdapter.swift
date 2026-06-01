// Compatible with: Facebook Audience Network 16.x
// Last verified: 2026-05-21
//
// NOTE: FAN is distributed via CocoaPods only — see FANBannerAdapter.swift
// for the SDK linking pattern. Adapter compiles as a placeholder when
// FBAudienceNetwork is not linkable.

import Foundation
import UIKit
import ExelBidSDK

#if canImport(FBAudienceNetwork)
import FBAudienceNetwork

public final class FANInterstitialAdapter: NSObject, InterstitialMediationAdapter {

    public static let networkID = "fan"
    public static var isAvailable: Bool { true }

    public var onWillAppear: (() -> Void)?
    public var onDidAppear: (() -> Void)?
    public var onWillDisappear: (() -> Void)?
    public var onDidDisappear: (() -> Void)?
    public var onClick: (() -> Void)?
    public var onLeaveApp: (() -> Void)?
    public var onClickFinish: (() -> Void)?

    private var interstitial: FBInterstitialAd?
    private var continuation: CheckedContinuation<Void, Error>?
    private var resumed = false

    public override init() { super.init() }

    public func load(
        unitId: String,
        rootViewController: UIViewController?,
        timeout: TimeInterval
    ) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            self.continuation = cont
            self.resumed = false
            DispatchQueue.main.async {
                let ad = FBInterstitialAd(placementID: unitId)
                ad.delegate = self
                ad.load()
                self.interstitial = ad
            }
        }
    }

    @MainActor
    public func present(from viewController: UIViewController) {
        interstitial?.show(fromRootViewController: viewController)
    }

    public func cancel() {
        interstitial?.delegate = nil
        interstitial = nil
        resume(throwing: CancellationError())
    }

    private func resume(returningSuccess: Void) {
        guard !resumed else { return }
        resumed = true
        continuation?.resume(returning: ()); continuation = nil
    }
    private func resume(throwing error: Error) {
        guard !resumed else { return }
        resumed = true
        continuation?.resume(throwing: error); continuation = nil
    }
}

extension FANInterstitialAdapter: FBInterstitialAdDelegate {
    public func interstitialAdDidLoad(_ interstitialAd: FBInterstitialAd) {
        resume(returningSuccess: ())
    }
    public func interstitialAd(_ interstitialAd: FBInterstitialAd, didFailWithError error: Error) {
        resume(throwing: error)
    }
    public func interstitialAdWillDisplay(_ interstitialAd: FBInterstitialAd) {
        onWillAppear?()
    }
    public func interstitialAdDidLogImpression(_ interstitialAd: FBInterstitialAd) {
        onDidAppear?()
    }
    public func interstitialAdWillClose(_ interstitialAd: FBInterstitialAd) {
        onWillDisappear?()
    }
    public func interstitialAdDidClose(_ interstitialAd: FBInterstitialAd) {
        onDidDisappear?()
    }
    public func interstitialAdDidClick(_ interstitialAd: FBInterstitialAd) {
        onClick?()
        onLeaveApp?()
    }
}

#else

public final class FANInterstitialAdapter: NSObject, InterstitialMediationAdapter {
    public static let networkID = "fan"
    public static var isAvailable: Bool { false }

    public var onWillAppear: (() -> Void)?
    public var onDidAppear: (() -> Void)?
    public var onWillDisappear: (() -> Void)?
    public var onDidDisappear: (() -> Void)?
    public var onClick: (() -> Void)?
    public var onLeaveApp: (() -> Void)?
    public var onClickFinish: (() -> Void)?

    public override init() { super.init() }

    public func load(unitId: String, rootViewController: UIViewController?, timeout: TimeInterval) async throws {
        throw FANInterstitialAdapterError.sdkNotLinked
    }
    public func present(from viewController: UIViewController) {}
    public func cancel() {}

    enum FANInterstitialAdapterError: Error { case sdkNotLinked }
}

#endif
