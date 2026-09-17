import XCTest
import UIKit
import GoogleMobileAds
import ExelBidSDK
@testable import ExelBidAdMobCustomEvent

@MainActor
final class NativeCustomEventTests: XCTestCase {

    // MARK: - Protocol conformance (runtime)

    private func makeAd() -> ExelBidMediationNativeAd {
        ExelBidMediationNativeAd(adUnitId: "unit-1", options: EBAdOptions(), imageLoadingDisabled: false)
    }

    func test_native_ad_conforms_to_MediationNativeAd() {
        XCTAssertTrue(makeAd() is MediationNativeAd)
    }

    /// Every rendering / tracking hook is an optional ObjC protocol member.
    /// A signature mismatch still compiles but GMA never calls it, so the
    /// selectors are pinned here.
    func test_optional_selectors_match_the_protocol() {
        let ad = makeAd()
        let selectors = [
            "handlesUserClicks",
            "handlesUserImpressions",
            "didRenderInView:clickableAssetViews:nonclickableAssetViews:viewController:",
            "didUntrackView:",
            "adChoicesView",
            "hasVideoContent",
            "mediaContentAspectRatio"
        ]
        for name in selectors {
            XCTAssertTrue(ad.responds(to: NSSelectorFromString(name)), "missing selector \(name)")
        }
    }

    func test_required_asset_selectors_are_exposed() {
        let ad = makeAd()
        for name in ["headline", "images", "body", "icon", "callToAction",
                     "starRating", "store", "price", "advertiser", "extraAssets"] {
            XCTAssertTrue(ad.responds(to: NSSelectorFromString(name)), "missing selector \(name)")
        }
    }

    func test_adapter_owns_click_and_impression_tracking() {
        let ad = makeAd()
        XCTAssertTrue(ad.handlesUserClicks())
        XCTAssertTrue(ad.handlesUserImpressions())
    }

    func test_phase1_is_image_only() {
        let ad = makeAd()
        XCTAssertFalse(ad.hasVideoContent)
        // No mediaView: GMA's own MediaView then displays images.first.
        XCTAssertFalse(ad.responds(to: NSSelectorFromString("mediaView")))
        XCTAssertFalse(NativeAssetMapping.requestedAssets.contains(.video))
        XCTAssertTrue(NativeAssetMapping.requestedAssets.contains(.main))
        XCTAssertTrue(NativeAssetMapping.requestedAssets.contains(.icon))
    }

    func test_adChoices_view_is_supplied() {
        XCTAssertNotNil(makeAd().adChoicesView)
    }

    // MARK: - Asset mapping

    private func decode(_ json: String) throws -> EBNativeAdModel {
        try JSONDecoder().decode(EBNativeAdModel.self, from: Data(json.utf8))
    }

    func test_mapping_carries_every_asset() throws {
        let model = try decode("""
        {"title":"Title","desc":"Body","desc2":"Body2","ctatext":"Install",
         "sponsored":"Brand","displayurl":"brand.com","icon":"https://cdn.example.com/i.png",
         "main":"https://cdn.example.com/m.png","logo":"https://cdn.example.com/l.png",
         "rating":"4.5","likes":"10","downloads":"1000","price":"$1","saleprice":"$0.5"}
        """)
        let m = NativeAssetMapping(model: model)
        XCTAssertEqual(m.headline, "Title")
        XCTAssertEqual(m.body, "Body")
        XCTAssertEqual(m.callToAction, "Install")
        XCTAssertEqual(m.advertiser, "Brand")
        XCTAssertEqual(m.price, "$1")
        XCTAssertEqual(m.starRating, NSDecimalNumber(string: "4.5"))
        XCTAssertEqual(m.iconURL?.absoluteString, "https://cdn.example.com/i.png")
        XCTAssertEqual(m.mainURL?.absoluteString, "https://cdn.example.com/m.png")
        XCTAssertEqual(m.extraAssets?["desc2"] as? String, "Body2")
        XCTAssertEqual(m.extraAssets?["displayurl"] as? String, "brand.com")
        XCTAssertEqual(m.extraAssets?["logo"] as? String, "https://cdn.example.com/l.png")
        XCTAssertEqual(m.extraAssets?["saleprice"] as? String, "$0.5")
    }

    func test_mapping_leaves_absent_assets_nil() throws {
        let m = NativeAssetMapping(model: try decode(#"{"title":"Only"}"#))
        XCTAssertEqual(m.headline, "Only")
        XCTAssertNil(m.body)
        XCTAssertNil(m.iconURL)
        XCTAssertNil(m.mainURL)
        XCTAssertNil(m.starRating)
        XCTAssertNil(m.extraAssets)
    }

    func test_starRating_accepts_only_0_to_5() {
        XCTAssertEqual(NativeAssetMapping.starRating(from: "0"), NSDecimalNumber.zero)
        XCTAssertEqual(NativeAssetMapping.starRating(from: "5"), NSDecimalNumber(value: 5))
        XCTAssertEqual(NativeAssetMapping.starRating(from: " 3.7 "), NSDecimalNumber(string: "3.7"))
        XCTAssertNil(NativeAssetMapping.starRating(from: "5.1"))
        XCTAssertNil(NativeAssetMapping.starRating(from: "-1"))
        XCTAssertNil(NativeAssetMapping.starRating(from: "abc"))
        XCTAssertNil(NativeAssetMapping.starRating(from: ""))
        XCTAssertNil(NativeAssetMapping.starRating(from: nil))
    }

    func test_image_loading_flag_follows_loader_options() {
        XCTAssertFalse(NativeAssetMapping.isImageLoadingDisabled([]))
        let enabled = NativeAdImageAdLoaderOptions()
        XCTAssertFalse(NativeAssetMapping.isImageLoadingDisabled([enabled]))
        let disabled = NativeAdImageAdLoaderOptions()
        disabled.isImageLoadingDisabled = true
        XCTAssertTrue(NativeAssetMapping.isImageLoadingDisabled([disabled]))
    }

    // MARK: - Overlay hit-testing

    /// Host layout with the common shape: assets wrapped in a container view,
    /// and an AdChoices icon in the top-right corner.
    private struct HostLayout {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        let headline = UILabel(frame: CGRect(x: 10, y: 10, width: 200, height: 20))
        let adChoices = UIView(frame: CGRect(x: 300, y: 0, width: 20, height: 20))
        let privacyIcon = UIImageView(frame: CGRect(x: 0, y: 0, width: 20, height: 20))

        init() {
            host.addSubview(container)
            container.addSubview(headline)
            adChoices.addSubview(privacyIcon)
            host.addSubview(adChoices)
            // The SDK enables interaction when it arms the privacy gesture.
            privacyIcon.isUserInteractionEnabled = true
        }

        func overlayOnTop() -> NativeTrackingOverlayView {
            let overlay = NativeTrackingOverlayView(frame: host.bounds)
            overlay.privacyIconView = privacyIcon
            overlay.passthroughViews = [privacyIcon]
            host.addSubview(overlay)
            return overlay
        }
    }

    func test_overlay_receives_taps_over_assets_inside_a_container() {
        let layout = HostLayout()
        let overlay = layout.overlayOnTop()
        XCTAssertTrue(layout.host.hitTest(CGPoint(x: 50, y: 20), with: nil) === overlay)
        XCTAssertTrue(layout.host.hitTest(CGPoint(x: 160, y: 150), with: nil) === overlay)
    }

    func test_overlay_lets_taps_through_to_a_visible_privacy_icon() {
        let layout = HostLayout()
        _ = layout.overlayOnTop()
        XCTAssertTrue(layout.host.hitTest(CGPoint(x: 310, y: 10), with: nil) === layout.privacyIcon)
    }

    func test_hidden_privacy_icon_area_counts_as_an_ad_click() {
        // The SDK hides the icon when the server sent no X-AdInfoUrl.
        let layout = HostLayout()
        let overlay = layout.overlayOnTop()
        layout.privacyIcon.isHidden = true
        XCTAssertTrue(layout.host.hitTest(CGPoint(x: 310, y: 10), with: nil) === overlay)
    }

    /// Documents why the overlay sits on top: placed underneath, the host's
    /// container view wins the hit test and a gesture on the overlay would
    /// never see the tap (UIKit delivers only to the hit view's ancestors).
    func test_overlay_underneath_would_lose_taps_to_the_container() {
        let layout = HostLayout()
        let overlay = NativeTrackingOverlayView(frame: layout.host.bounds)
        layout.host.insertSubview(overlay, at: 0)
        let hit = layout.host.hitTest(CGPoint(x: 160, y: 150), with: nil)
        XCTAssertTrue(hit === layout.container)
        XCTAssertFalse(hit === overlay)
    }

    func test_overlay_exposes_only_the_privacy_slot() {
        let layout = HostLayout()
        let overlay = layout.overlayOnTop()
        let rendering: EBNativeAdRendering = overlay
        XCTAssertTrue(rendering.nativePrivacyInformationIconImageView?() === layout.privacyIcon)
        XCTAssertNil(rendering.nativeTitleTextLabel?() ?? nil)
        XCTAssertNil(rendering.nativeMediaView?() ?? nil)
        XCTAssertNil(rendering.nativeCallToActionButton?() ?? nil)
    }
}
