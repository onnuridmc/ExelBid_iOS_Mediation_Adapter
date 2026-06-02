// Compatible with: Facebook Audience Network 16.x
// Last verified: 2026-05-21
//
// Uses `FBRewardedVideoAd` as the closest semantic match for v3's
// `EBVideoAd` (fullscreen video). FAN exposes no quartile callbacks; we
// approximate `onProgress(0)` at present and `onProgress(100)` on
// video-complete via the rewarded callback.

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

    private var rewarded: FBRewardedVideoAd?
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
                let ad = FBRewardedVideoAd(placementID: unitId)
                ad.delegate = self
                ad.load()
                self.rewarded = ad
            }
        }
    }

    @MainActor
    public func present(from viewController: UIViewController) {
        rewarded?.show(fromRootViewController: viewController)
        onProgress?(0)
    }

    public func cancel() {
        rewarded?.delegate = nil
        rewarded = nil
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

extension FANVideoAdapter: FBRewardedVideoAdDelegate {
    public func rewardedVideoAdDidLoad(_ rewardedVideoAd: FBRewardedVideoAd) {
        resume(returningSuccess: ())
    }
    public func rewardedVideoAd(_ rewardedVideoAd: FBRewardedVideoAd, didFailWithError error: Error) {
        resume(throwing: error)
    }
    public func rewardedVideoAdWillLogImpression(_ rewardedVideoAd: FBRewardedVideoAd) {
        onWillAppear?()
    }
    public func rewardedVideoAdVideoComplete(_ rewardedVideoAd: FBRewardedVideoAd) {
        onProgress?(100)
    }
    public func rewardedVideoAdWillClose(_ rewardedVideoAd: FBRewardedVideoAd) {
        onWillDisappear?()
    }
    public func rewardedVideoAdDidClose(_ rewardedVideoAd: FBRewardedVideoAd) {
        onDidDisappear?()
    }
    public func rewardedVideoAdDidClick(_ rewardedVideoAd: FBRewardedVideoAd) {
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
