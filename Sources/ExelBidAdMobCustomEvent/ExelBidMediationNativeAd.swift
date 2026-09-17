// Compatible with: Google Mobile Ads SDK 12.x / 13.x

import Foundation
import UIKit
import ExelBidSDK
import GoogleMobileAds

/// A loaded ExelBid native ad handed to the Google Mobile Ads SDK.
///
/// The host renders the assets into its own `NativeAdView`; this object only
/// supplies data. ExelBid's impression / click / MRC visibility tracking is
/// reachable solely through `EBNativeAd.attach(to:)`, so on `didRender` a
/// transparent `NativeTrackingOverlayView` is laid over the host view and
/// attached. Because the adapter tracks on its own, `handlesUserClicks` and
/// `handlesUserImpressions` return `true` and results are reported through
/// the event delegate.
///
/// Phase 1 is image-only: no `mediaView` is supplied, so GMA's `MediaView`
/// shows `images.first`, and `hasVideoContent` is `false`.
final class ExelBidMediationNativeAd: NSObject, MediationNativeAd {

    // MARK: - MediatedUnifiedNativeAd assets

    private(set) var headline: String?
    private(set) var images: [NativeAdImage]?
    private(set) var body: String?
    private(set) var icon: NativeAdImage?
    private(set) var callToAction: String?
    private(set) var starRating: NSDecimalNumber?
    /// ExelBid has no app-store name asset.
    var store: String? { nil }
    private(set) var price: String?
    private(set) var advertiser: String?
    private(set) var extraAssets: [String: Any]?

    var adChoicesView: UIView? { adChoicesContainer }
    var hasVideoContent: Bool { false }
    private(set) var mediaContentAspectRatio: CGFloat = 0

    // MARK: - State

    private let loader: EBNativeAdLoader
    private let imageLoadingDisabled: Bool
    private var nativeAd: EBNativeAd?
    private var completionHandler: GADMediationNativeLoadCompletionHandler?
    private var eventDelegate: MediationNativeAdEventDelegate?
    /// Keeps the instance alive between `load()` and the completion handler.
    private var selfRetain: ExelBidMediationNativeAd?
    private var overlay: NativeTrackingOverlayView?

    /// Handed to GMA as `adChoicesView`. The SDK renders its privacy icon
    /// into `privacyIconView` — or hides it when there is no `X-AdInfoUrl`.
    private let adChoicesContainer = UIView(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
    private let privacyIconView = UIImageView(frame: CGRect(x: 0, y: 0, width: 20, height: 20))

    // MARK: - Init

    init(adUnitId: String, options: EBAdOptions, imageLoadingDisabled: Bool) {
        loader = EBNativeAdLoader(adUnitId: adUnitId)
        loader.options = options
        loader.desiredAssets = NativeAssetMapping.requestedAssets
        self.imageLoadingDisabled = imageLoadingDisabled
        super.init()

        privacyIconView.contentMode = .scaleAspectFit
        privacyIconView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        privacyIconView.isHidden = true
        adChoicesContainer.addSubview(privacyIconView)
    }

    // MARK: - Loading

    func load(completionHandler: @escaping GADMediationNativeLoadCompletionHandler) {
        self.completionHandler = completionHandler
        self.selfRetain = self

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            do {
                let ad = try await self.loader.load()
                await self.applyAssets(of: ad)
                self.nativeAd = ad
                self.finishLoading(with: nil)
            } catch let error as EBAdError {
                self.finishLoading(with: error.asNSError)
            } catch {
                self.finishLoading(with: error as NSError)
            }
        }
    }

    @MainActor
    private func applyAssets(of ad: EBNativeAd) async {
        let mapping = NativeAssetMapping(model: ad.model)
        headline = mapping.headline
        body = mapping.body
        callToAction = mapping.callToAction
        price = mapping.price
        advertiser = mapping.advertiser
        starRating = mapping.starRating
        extraAssets = mapping.extraAssets

        if imageLoadingDisabled {
            icon = mapping.iconURL.map { NativeAdImage(url: $0, scale: 1) }
            images = mapping.mainURL.map { [NativeAdImage(url: $0, scale: 1)] }
            return
        }

        async let iconImage = NativeAssetMapping.fetchImage(at: mapping.iconURL)
        async let mainImage = NativeAssetMapping.fetchImage(at: mapping.mainURL)
        let (loadedIcon, loadedMain) = await (iconImage, mainImage)

        icon = loadedIcon.map { NativeAdImage(image: $0) }
        if let main = loadedMain {
            images = [NativeAdImage(image: main)]
            if main.size.height > 0 {
                mediaContentAspectRatio = main.size.width / main.size.height
            }
        }
    }

    private func finishLoading(with error: NSError?) {
        guard let handler = completionHandler else { return }
        completionHandler = nil
        defer { selfRetain = nil }

        if let error = error {
            _ = handler(nil, error)
        } else {
            eventDelegate = handler(self, nil)
        }
    }

    // MARK: - MediationNativeAd

    func handlesUserClicks() -> Bool { true }

    func handlesUserImpressions() -> Bool { true }

    // MARK: - MediatedUnifiedNativeAd rendering

    func didRender(
        in view: UIView,
        clickableAssetViews: [GADNativeAssetIdentifier: UIView],
        nonclickableAssetViews: [GADNativeAssetIdentifier: UIView],
        viewController: UIViewController
    ) {
        MainActor.assumeIsolated {
            guard let ad = nativeAd else { return }

            overlay?.removeFromSuperview()
            let overlay = NativeTrackingOverlayView(frame: view.bounds)
            overlay.privacyIconView = privacyIconView
            overlay.passthroughViews = [privacyIconView]
            view.addSubview(overlay)
            self.overlay = overlay

            ad.presenterProvider = { [weak viewController] in viewController }
            // `attach` fires the base impression immediately, the same moment
            // this reports it to GMA.
            ad.onImpression = { [weak self] in self?.eventDelegate?.reportImpression() }
            ad.onClick = { [weak self] in self?.eventDelegate?.reportClick() }
            // `onLeaveApp` / `onClickFinish` are not forwarded: EBNativeAd has
            // no matching "will present" signal, and reporting only the
            // dismissal would leave GMA with an unbalanced full-screen pair.
            ad.attach(to: overlay)
        }
    }

    func didUntrackView(_ view: UIView?) {
        MainActor.assumeIsolated {
            nativeAd?.detach()
            overlay?.removeFromSuperview()
            overlay = nil
        }
    }
}
