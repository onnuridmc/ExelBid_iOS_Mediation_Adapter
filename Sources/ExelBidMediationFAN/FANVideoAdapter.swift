// Compatible with: Facebook Audience Network 16.x
//
// For non-ExelBid networks, v3's mediation "video" format means a
// FULLSCREEN INTERSTITIAL VIDEO (전면 비디오) — NOT a rewarded ad. So this
// adapter wraps FAN's `FBInterstitialAd` (a video placement serves its
// video creative through the fullscreen interstitial surface). FAN exposes
// no quartile callbacks for interstitials, so `onProgress` is approximated —
// 0 at present, 100 on close (treated as end-of-playback).

import Foundation
import UIKit
import ExelBidSDK

#if canImport(FBAudienceNetwork)
import FBAudienceNetwork

public final class FANVideoAdapter: NSObject, EBVideoMediationAdapter {

    public static let networkID = "fan"
    public static var isAvailable: Bool { true }

    public var onWillAppear: (() -> Void)?
    public var onDidAppear: (() -> Void)?
    public var onWillDisappear: (() -> Void)?
    public var onDidDisappear: (() -> Void)?
    public var onClick: (() -> Void)?
    public var onLeaveApp: (() -> Void)?
    public var onProgress: ((Int) -> Void)?

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
        onProgress?(0)
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

extension FANVideoAdapter: FBInterstitialAdDelegate {
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
        // FAN exposes no quartile / complete callback for interstitials;
        // treat close as end-of-playback.
        onProgress?(100)
        onDidDisappear?()
    }
    public func interstitialAdDidClick(_ interstitialAd: FBInterstitialAd) {
        onClick?()
        onLeaveApp?()
    }
}

#else

public final class FANVideoAdapter: NSObject, EBVideoMediationAdapter {
    public static let networkID = "fan"
    public static var isAvailable: Bool { false }

    public var onWillAppear: (() -> Void)?
    public var onDidAppear: (() -> Void)?
    public var onWillDisappear: (() -> Void)?
    public var onDidDisappear: (() -> Void)?
    public var onClick: (() -> Void)?
    public var onLeaveApp: (() -> Void)?
    public var onProgress: ((Int) -> Void)?

    public override init() { super.init() }

    public func load(unitId: String, rootViewController: UIViewController?, timeout: TimeInterval) async throws {
        throw FANVideoAdapterError.sdkNotLinked
    }
    public func present(from viewController: UIViewController) {}
    public func cancel() {}

    enum FANVideoAdapterError: Error { case sdkNotLinked }
}

#endif
