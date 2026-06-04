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
                 from: "3.0.0"),

        // Per-network SDKs. The listed version is the minimum supported major.
        .package(
            url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git",
            from: "12.0.0"
        ),
        // Facebook Audience Network (FAN) and Kakao AdFit are NOT
        // available via SwiftPM. Hosts that use these adapters must
        // link the third-party SDK themselves (CocoaPods, Carthage,
        // or a manual binary target). The adapter files use
        // `#if canImport(...)` so they compile here as no-op
        // placeholders (isAvailable == false), and the real
        // implementation is enabled automatically once the host links
        // the missing SDK.
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
                .product(name: "ExelBidSDK", package: "ExelBid_iOS_Swift")
                // AdFitSDK: host links it via CocoaPods / manual
                // binary target. Adapter is guarded with
                // `#if canImport(AdFitSDK)`.
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
