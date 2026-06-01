import XCTest
import ExelBidSDK
@testable import ExelBidMediationAdMob
@testable import ExelBidMediationFAN
@testable import ExelBidMediationAdFit

final class AdapterRegistrationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MediationRegistry.shared.removeAllForTesting()
    }

    override func tearDown() {
        MediationRegistry.shared.removeAllForTesting()
        super.tearDown()
    }

    func test_admob_module_registers_banner_adapter() {
        AdMobMediationModule.register(in: MediationRegistry.shared)
        let resolved = MediationRegistry.shared.bannerAdapter(for: "admob")
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.networkID, "admob")
    }

    func test_admob_module_registers_all_four_formats() {
        AdMobMediationModule.register(in: MediationRegistry.shared)
        XCTAssertNotNil(MediationRegistry.shared.bannerAdapter(for: "admob"))
        XCTAssertNotNil(MediationRegistry.shared.interstitialAdapter(for: "admob"))
        XCTAssertNotNil(MediationRegistry.shared.nativeAdapter(for: "admob"))
        XCTAssertNotNil(MediationRegistry.shared.videoAdapter(for: "admob"))
    }

    func test_fan_module_registers_banner_adapter() {
        FANMediationModule.register(in: MediationRegistry.shared)
        XCTAssertEqual(
            MediationRegistry.shared.bannerAdapter(for: "fan")?.networkID,
            "fan"
        )
    }

    func test_fan_module_registers_all_four_formats() {
        FANMediationModule.register(in: MediationRegistry.shared)
        XCTAssertNotNil(MediationRegistry.shared.bannerAdapter(for: "fan"))
        XCTAssertNotNil(MediationRegistry.shared.interstitialAdapter(for: "fan"))
        XCTAssertNotNil(MediationRegistry.shared.nativeAdapter(for: "fan"))
        XCTAssertNotNil(MediationRegistry.shared.videoAdapter(for: "fan"))
    }

    func test_adfit_module_registers_banner_adapter() {
        AdFitMediationModule.register(in: MediationRegistry.shared)
        XCTAssertEqual(
            MediationRegistry.shared.bannerAdapter(for: "adfit")?.networkID,
            "adfit"
        )
    }

    func test_adfit_module_registers_banner_interstitial_native() {
        AdFitMediationModule.register(in: MediationRegistry.shared)
        XCTAssertNotNil(MediationRegistry.shared.bannerAdapter(for: "adfit"))
        XCTAssertNotNil(MediationRegistry.shared.interstitialAdapter(for: "adfit"))
        XCTAssertNotNil(MediationRegistry.shared.nativeAdapter(for: "adfit"))
        // AdFit SDK has no video format — verify no video registration
        XCTAssertNil(MediationRegistry.shared.videoAdapter(for: "adfit"))
    }

    func test_kit_register_multiple_modules() {
        ExelBidMediationKit.shared.register(modules: [
            AdMobMediationModule.self,
            FANMediationModule.self,
            AdFitMediationModule.self
        ])
        XCTAssertEqual(
            Set(MediationRegistry.shared.registeredBannerNetworks()),
            Set(["admob", "fan", "adfit"])
        )
    }
}
