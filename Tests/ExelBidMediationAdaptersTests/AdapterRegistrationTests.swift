import XCTest
import ExelBidSDK
@testable import ExelBidMediationAdMob
@testable import ExelBidMediationFAN
@testable import ExelBidMediationAdFit

final class AdapterRegistrationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        EBMediationRegistry.shared.removeAllForTesting()
    }

    override func tearDown() {
        EBMediationRegistry.shared.removeAllForTesting()
        super.tearDown()
    }

    func test_admob_module_registers_banner_adapter() {
        AdMobMediationModule.register(in: EBMediationRegistry.shared)
        let resolved = EBMediationRegistry.shared.bannerAdapter(for: "admob")
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.networkID, "admob")
    }

    func test_admob_module_registers_all_four_formats() {
        AdMobMediationModule.register(in: EBMediationRegistry.shared)
        XCTAssertNotNil(EBMediationRegistry.shared.bannerAdapter(for: "admob"))
        XCTAssertNotNil(EBMediationRegistry.shared.interstitialAdapter(for: "admob"))
        XCTAssertNotNil(EBMediationRegistry.shared.nativeAdapter(for: "admob"))
        XCTAssertNotNil(EBMediationRegistry.shared.videoAdapter(for: "admob"))
    }

    func test_fan_module_registers_banner_adapter() {
        FANMediationModule.register(in: EBMediationRegistry.shared)
        XCTAssertEqual(
            EBMediationRegistry.shared.bannerAdapter(for: "fan")?.networkID,
            "fan"
        )
    }

    func test_fan_module_registers_all_four_formats() {
        FANMediationModule.register(in: EBMediationRegistry.shared)
        XCTAssertNotNil(EBMediationRegistry.shared.bannerAdapter(for: "fan"))
        XCTAssertNotNil(EBMediationRegistry.shared.interstitialAdapter(for: "fan"))
        XCTAssertNotNil(EBMediationRegistry.shared.nativeAdapter(for: "fan"))
        XCTAssertNotNil(EBMediationRegistry.shared.videoAdapter(for: "fan"))
    }

    func test_adfit_module_registers_banner_adapter() {
        AdFitMediationModule.register(in: EBMediationRegistry.shared)
        XCTAssertEqual(
            EBMediationRegistry.shared.bannerAdapter(for: "adfit")?.networkID,
            "adfit"
        )
    }

    func test_adfit_module_registers_banner_interstitial_native() {
        AdFitMediationModule.register(in: EBMediationRegistry.shared)
        XCTAssertNotNil(EBMediationRegistry.shared.bannerAdapter(for: "adfit"))
        XCTAssertNotNil(EBMediationRegistry.shared.interstitialAdapter(for: "adfit"))
        XCTAssertNotNil(EBMediationRegistry.shared.nativeAdapter(for: "adfit"))
        // AdFit SDK has no video format — verify no video registration
        XCTAssertNil(EBMediationRegistry.shared.videoAdapter(for: "adfit"))
    }

    func test_kit_register_multiple_modules() {
        ExelBidMediationKit.shared.register(modules: [
            AdMobMediationModule.self,
            FANMediationModule.self,
            AdFitMediationModule.self
        ])
        XCTAssertEqual(
            Set(EBMediationRegistry.shared.registeredBannerNetworks()),
            Set(["admob", "fan", "adfit"])
        )
    }
}
