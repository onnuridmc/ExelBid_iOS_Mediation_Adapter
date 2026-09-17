// Compatible with: Google Mobile Ads SDK 12.x / 13.x

import UIKit
import ExelBidSDK

/// Transparent view laid on top of the host's `NativeAdView` so that
/// `EBNativeAd.attach(to:)` can arm its click gesture and visibility timers
/// without owning the host's layout.
///
/// Why on top, not underneath: UIKit delivers a tap only to the hit-tested
/// view and its ancestors, never to siblings. Host layouts routinely wrap
/// their labels in a container view (plain `UIView`, `UIStackView`), and such
/// a container swallows the hit before a sibling underneath could see it.
/// Sitting on top guarantees the overlay is the hit-tested view.
///
/// Touches that must keep reaching the views below — the AdChoices icon —
/// are let through by returning `false` from `point(inside:with:)` over
/// `passthroughViews`.
///
/// Every `EBNativeAdRendering` slot is left unimplemented except the privacy
/// icon, so the SDK's renderer never overwrites what the host already drew.
/// The privacy slot returns an image view that lives inside the
/// `adChoicesView` handed to GMA, not inside this overlay — the renderer only
/// needs a reference to it.
final class NativeTrackingOverlayView: UIView, EBNativeAdRendering {

    /// Views whose touches pass through the overlay to what is underneath.
    var passthroughViews: [UIView] = []

    /// The AdChoices image view the SDK populates (or hides when the server
    /// sent no `X-AdInfoUrl`).
    weak var privacyIconView: UIImageView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isAccessibilityElement = false
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Not supported") }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        for view in passthroughViews
        where view.window === window && !view.isHidden && view.alpha > 0.01 {
            if view.bounds.contains(view.convert(point, from: self)) {
                return false
            }
        }
        return super.point(inside: point, with: event)
    }

    // MARK: - EBNativeAdRendering

    func nativePrivacyInformationIconImageView() -> UIImageView? {
        privacyIconView
    }
}
