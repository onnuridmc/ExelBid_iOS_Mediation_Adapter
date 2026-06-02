// Compatible with: Kakao AdFit SDK 3.x
// Last verified: 2026-05-21
//
// AdFit is distributed via CocoaPods only — see AdFitBannerAdapter.swift
// for the SDK linking pattern.

import Foundation
import UIKit
import ExelBidSDK

#if canImport(AdFitSDK)
import AdFitSDK

public final class AdFitInterstitialAdapter: NSObject, EBInterstitialMediationAdapter {

    public static let networkID = "adfit"
    public static var isAvailable: Bool { true }

    public var onWillAppear: (() -> Void)?
    public var onDidAppear: (() -> Void)?
    public var onWillDisappear: (() -> Void)?
    public var onDidDisappear: (() -> Void)?
    public var onClick: (() -> Void)?
    public var onLeaveApp: (() -> Void)?
    public var onClickFinish: (() -> Void)?

    private var interstitial: AdFitInterstitialAd?
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
                let ad = AdFitInterstitialAd(clientId: unitId)
                ad.delegate = self
                ad.loadAd()
                self.interstitial = ad
            }
        }
    }

    @MainActor
    public func present(from viewController: UIViewController) {
        interstitial?.show(from: viewController)
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

extension AdFitInterstitialAdapter: AdFitInterstitialAdDelegate {
    public func adFitInterstitialAdDidReceiveAd(_ interstitialAd: AdFitInterstitialAd) {
        resume(returningSuccess: ())
    }
    public func adFitInterstitialAd(
        _ interstitialAd: AdFitInterstitialAd,
        didFailToReceiveAdWithError error: Error
    ) {
        resume(throwing: error)
    }
    public func adFitInterstitialAdDidClickAd(_ interstitialAd: AdFitInterstitialAd) {
        onClick?()
    }
    public func adFitInterstitialAdWillPresent(_ interstitialAd: AdFitInterstitialAd) {
        onWillAppear?()
    }
    public func adFitInterstitialAdDidPresent(_ interstitialAd: AdFitInterstitialAd) {
        onDidAppear?()
    }
    public func adFitInterstitialAdWillDismiss(_ interstitialAd: AdFitInterstitialAd) {
        onWillDisappear?()
    }
    public func adFitInterstitialAdDidDismiss(_ interstitialAd: AdFitInterstitialAd) {
        onDidDisappear?()
    }
}

#else

public final class AdFitInterstitialAdapter: NSObject, EBInterstitialMediationAdapter {
    public static let networkID = "adfit"
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
        throw AdFitInterstitialAdapterError.sdkNotLinked
    }
    public func present(from viewController: UIViewController) {}
    public func cancel() {}

    enum AdFitInterstitialAdapterError: Error { case sdkNotLinked }
}

#endif
