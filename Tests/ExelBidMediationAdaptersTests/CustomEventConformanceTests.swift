import XCTest
import GoogleMobileAds
@testable import ExelBidAdMobCustomEvent

/// The Google Mobile Ads SDK resolves a custom event through the Objective-C
/// runtime and calls its format methods via optional protocol selectors.
/// Swift compiles a *mismatched* optional-method signature without complaint —
/// it just becomes an unrelated method GMA never calls — so conformance has to
/// be asserted at runtime, not by the type checker.
final class CustomEventConformanceTests: XCTestCase {

    func test_class_is_reachable_by_the_name_entered_in_the_admob_console() {
        // "Class Name" field in the AdMob console.
        let cls = NSClassFromString("ExelBidCustomEvent")
        XCTAssertNotNil(cls, "GMA looks the custom event up by this exact name")
        XCTAssertTrue(cls is ExelBidCustomEvent.Type)
    }

    func test_adapter_conforms_to_MediationAdapter() {
        XCTAssertTrue(ExelBidCustomEvent() is MediationAdapter)
    }

    func test_banner_load_selector_matches_the_protocol() {
        let adapter = ExelBidCustomEvent()
        XCTAssertTrue(
            adapter.responds(to: NSSelectorFromString("loadBannerForAdConfiguration:completionHandler:")),
            "GMA sends this exact selector to load a banner"
        )
    }

    func test_setUp_class_selector_matches_the_protocol() {
        XCTAssertTrue(
            ExelBidCustomEvent.responds(to: NSSelectorFromString("setUpWithConfiguration:completionHandler:")),
            "GMA sends this class selector once, before the first ad request"
        )
    }

    func test_interstitial_load_selector_matches_the_protocol() {
        let adapter = ExelBidCustomEvent()
        XCTAssertTrue(
            adapter.responds(to: NSSelectorFromString("loadInterstitialForAdConfiguration:completionHandler:")),
            "GMA sends this exact selector to load an interstitial"
        )
    }

    func test_native_load_selector_matches_the_protocol() {
        let adapter = ExelBidCustomEvent()
        XCTAssertTrue(
            adapter.responds(to: NSSelectorFromString("loadNativeAdForAdConfiguration:completionHandler:")),
            "GMA sends this exact selector to load a native ad"
        )
    }

    func test_unimplemented_formats_are_reported_as_unsupported() {
        let adapter = ExelBidCustomEvent()
        // Banner, interstitial and native ship. GMA checks respondsToSelector
        // before dispatching, so these must stay false until the formats land.
        XCTAssertFalse(adapter.responds(to: NSSelectorFromString("loadRewardedAdForAdConfiguration:completionHandler:")))
        XCTAssertFalse(adapter.responds(to: NSSelectorFromString("loadRewardedInterstitialAdForAdConfiguration:completionHandler:")))
        XCTAssertFalse(adapter.responds(to: NSSelectorFromString("loadAppOpenAdForAdConfiguration:completionHandler:")))
    }

    func test_versions_are_reported() {
        let adapter = ExelBidCustomEvent.adapterVersion()
        XCTAssertEqual(adapter.majorVersion, 1)

        // Parsed from ExelBid.shared.sdkVersion.
        let sdk = ExelBidCustomEvent.adSDKVersion()
        XCTAssertGreaterThanOrEqual(sdk.majorVersion, 3)
    }

    func test_extras_class_is_advertised() {
        XCTAssertTrue(ExelBidCustomEvent.networkExtrasClass() == ExelBidAdMobExtras.self)
    }
}
