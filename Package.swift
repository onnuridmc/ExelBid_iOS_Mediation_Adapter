// swift-tools-version: 5.9
import PackageDescription

// Third-party adapter modules for the ExelBid iOS SDK mediation. Each
// adapter is its own SwiftPM product so host apps link only the adapter
// SDKs they use. The mediation core (orchestrator, protocols, registry)
// ships with the `ExelBidSDK` product.
let package = Package(
    name: "ExelBidMediationAdapters",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(name: "ExelBidMediationAdMob",
                 targets: ["ExelBidMediationAdMob"]),
        .library(name: "ExelBidMediationFAN",
                 targets: ["ExelBidMediationFAN"]),
        .library(name: "ExelBidMediationAdFit",
                 targets: ["ExelBidMediationAdFit"]),
    ],
    dependencies: [
        // ExelBid iOS SDK — provides the mediation core every adapter builds on.
        .package(url: "https://github.com/onnuridmc/ExelBid_iOS_Swift",
                 from: "3.0.8"),

        // Per-network SDKs. The listed version is the minimum supported major.
        // GoogleMobileAds spans two majors: 12.x and 13.x are both supported
        // and verified to type-check. `from:` is `.upToNextMajor` and would
        // cap this at 12.x, so the range is spelled out. 14.x is excluded
        // until the adapter is built against it — 13.0 deprecated
        // `currentOrientationAnchoredAdaptiveBanner(width:)`, which is a
        // likely removal in 14 and would break host builds.
        .package(
            url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git",
            "12.0.0" ..< "14.0.0"
        ),
        // Kakao AdFit ships an official SwiftPM package (binary xcframework).
        .package(url: "https://github.com/adfit/adfit-spm", from: "3.21.0"),
        // Facebook Audience Network (FAN) is NOT available via SwiftPM.
        // Hosts that use the FAN adapter must link `FBAudienceNetwork`
        // themselves (CocoaPods, Carthage, or a manual binary target).
        // The FAN adapter is guarded with `#if canImport(FBAudienceNetwork)`
        // so it compiles here as a no-op placeholder (isAvailable == false)
        // and switches to the real implementation once the host links it.
    ],
    targets: [
        .target(
            name: "ExelBidMediationAdMob",
            dependencies: [
                .product(name: "ExelBidSDK", package: "ExelBid_iOS_Swift"),
                .product(name: "GoogleMobileAds",
                         package: "swift-package-manager-google-mobile-ads")
            ],
            path: "Sources/ExelBidMediationAdMob"
        ),
        .target(
            name: "ExelBidMediationFAN",
            dependencies: [
                .product(name: "ExelBidSDK", package: "ExelBid_iOS_Swift")
                // FBAudienceNetwork: host links it via CocoaPods /
                // Carthage / binary target. Adapter is guarded with
                // `#if canImport(FBAudienceNetwork)`.
            ],
            path: "Sources/ExelBidMediationFAN"
        ),
        .target(
            name: "ExelBidMediationAdFit",
            dependencies: [
                .product(name: "ExelBidSDK", package: "ExelBid_iOS_Swift"),
                .product(name: "AdFitSDK", package: "adfit-spm")
            ],
            path: "Sources/ExelBidMediationAdFit"
        ),

        // Smoke-test target covering adapter registration.
        .testTarget(
            name: "ExelBidMediationAdaptersTests",
            dependencies: [
                "ExelBidMediationAdMob",
                "ExelBidMediationFAN",
                "ExelBidMediationAdFit",
                .product(name: "ExelBidSDK", package: "ExelBid_iOS_Swift")
            ],
            path: "Tests/ExelBidMediationAdaptersTests"
        )
    ],
    swiftLanguageVersions: [.v5]
)
