// swift-tools-version: 5.9
import PackageDescription

// Third-party adapter modules for ExelBidMediation. Each adapter is its
// own SwiftPM product so host apps link only the adapter SDKs they use.
//
// The mediation core (orchestrator, protocols, registry) lives in the
// `exelbid-ios-sdk-v3` repo and is consumed via the `ExelBidMediation`
// product. During local development we depend on it by relative path.
// Release builds will switch to a versioned package URL.
let package = Package(
    name: "ExelBidMediationAdapters",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        // Tier 1 — operationally mandatory for KR market.
        .library(name: "ExelBidMediationAdMob",
                 targets: ["ExelBidMediationAdMob"]),
        .library(name: "ExelBidMediationFAN",
                 targets: ["ExelBidMediationFAN"]),
        .library(name: "ExelBidMediationAdFit",
                 targets: ["ExelBidMediationAdFit"]),
    ],
    dependencies: [
        // Local path during development; switch to a versioned URL
        // (`https://github.com/.../exelbid-ios-sdk-v3.git`) at release.
        .package(url: "https://github.com/onnuridmc/ExelBid_iOS_Swift", from: "3.0.0"),

        // Per-network SDKs. Versions are *minimum* — adapters should
        // remain source-compatible with the listed major version range.
        // Update when a third-party SDK introduces breaking changes
        // (see top-of-file comment in each adapter).
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
                .product(name: "ExelBidSDK", package: "ExelBidSDK"),
                .product(name: "GoogleMobileAds",
                         package: "swift-package-manager-google-mobile-ads")
            ],
            path: "Sources/ExelBidMediationAdMob"
        ),
        .target(
            name: "ExelBidMediationFAN",
            dependencies: [
                .product(name: "ExelBidSDK", package: "ExelBidSDK")
                // FBAudienceNetwork: host links it via CocoaPods /
                // Carthage / binary target. Adapter is guarded with
                // `#if canImport(FBAudienceNetwork)`.
            ],
            path: "Sources/ExelBidMediationFAN"
        ),
        .target(
            name: "ExelBidMediationAdFit",
            dependencies: [
                .product(name: "ExelBidSDK", package: "ExelBidSDK")
                // AdFitSDK: host links it via CocoaPods / manual
                // binary target. Adapter is guarded with
                // `#if canImport(AdFitSDK)`.
            ],
            path: "Sources/ExelBidMediationAdFit"
        ),

        // Tests live with each adapter when there's something
        // meaningful to test in isolation. For now we keep a single
        // light smoke-test target.
        .testTarget(
            name: "ExelBidMediationAdaptersTests",
            dependencies: [
                "ExelBidMediationAdMob",
                "ExelBidMediationFAN",
                "ExelBidMediationAdFit",
                .product(name: "ExelBidSDK", package: "ExelBidSDK")
            ],
            path: "Tests/ExelBidMediationAdaptersTests"
        )
    ],
    swiftLanguageVersions: [.v5]
)
