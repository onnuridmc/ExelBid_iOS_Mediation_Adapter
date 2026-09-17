// Compatible with: Google Mobile Ads SDK 12.x / 13.x

import Foundation
import ExelBidSDK
import GoogleMobileAds

/// Per-request ExelBid targeting for hosts whose mediation is AdMob.
///
/// `MediationAdConfiguration` exposes no keyword / COPPA / demographics
/// fields, so `AdNetworkExtras` is the only way for the host to reach the
/// ExelBid request builder:
///
/// ```swift
/// let extras = ExelBidAdMobExtras()
/// extras.options.keywords = ["channel": "sport"]
/// extras.options.yearOfBirth = 1990
///
/// let request = Request()
/// request.register(extras)
/// bannerView.load(request)
/// ```
@objc(ExelBidAdMobExtras)
public final class ExelBidAdMobExtras: NSObject, AdNetworkExtras {

    /// Forwarded verbatim to the ExelBid ad request.
    @objc public var options: EBAdOptions

    @objc public override convenience init() {
        self.init(options: EBAdOptions())
    }

    @objc public init(options: EBAdOptions) {
        self.options = options
        super.init()
    }
}
