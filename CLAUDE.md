# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A SwiftPM package (`ExelBidMediationAdapters`) of **third-party network adapters** for ExelBid iOS SDK v3 mediation. It contains *only* the thin bridges between each ad network's iOS SDK and the ExelBid mediation contract. The orchestrator, protocols, registry, and the built-in ExelBid adapter all live in the sibling repo `exelbid-ios-sdk-v3` and are consumed here via the `ExelBidSDK` product.

Each adapter ships as a **separate SwiftPM library product** so host apps link only the network SDKs they actually use.

## Dependency on the sibling SDK

`Package.swift` depends on `ExelBidSDK` by **relative path** (`../exelbid-ios-sdk-v3`) during development. This sibling checkout must exist for the package to resolve and build. Release builds swap this for a versioned package URL — when editing `Package.swift`, preserve the local-path-vs-release-URL distinction noted in its comments.

## Commands

```bash
# Build a single adapter for the simulator (resolves the relative-path SDK dep)
DEST=$(xcrun simctl list devices available | grep -E "iPhone [0-9]+ \(" \
       | head -1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')
xcodebuild -scheme ExelBidMediationAdMob \
  -destination "platform=iOS Simulator,id=$DEST" build

# Run the full test suite (SwiftPM)
swift test

# Run a single test
swift test --filter AdapterRegistrationTests/test_admob_module_registers_all_four_formats
```

There is no linter configured. First build pulls third-party SDKs into the SwiftPM cache; subsequent builds reuse them.

## Architecture

The contract (defined in `ExelBidSDK`, not here):
- **`MediationModule`** — a registration entry point. Each network exposes one as an `enum` with a single static `register(in: MediationRegistry)` method.
- **Format adapter protocols** — `BannerMediationAdapter`, `InterstitialMediationAdapter`, `NativeMediationAdapter`, `VideoMediationAdapter`. Each adapter declares `static let networkID`, `static var isAvailable`, and an `async throws` `load(...)` returning the rendered ad.
- **`MediationRegistry`** — maps `networkID` → adapter type, per format. The server-driven waterfall resolves networks by `networkID` string.
- **`ExelBidMediationKit.shared.register(modules:)`** — host calls this once at launch with the module types it wants.

### Per-network layout

Each network is one directory under `Sources/ExelBidMediation<Network>/` containing:
- `<Network>MediationModule.swift` — the module enum; its `register(in:)` wires each format adapter into the registry.
- `<Network>{Banner,Interstitial,Native,Video}Adapter.swift` — the concrete bridges.

Active networks: **AdMob** (`admob`, SwiftPM-distributed, all 4 formats), **FAN** (`fan`, host-linked), **AdFit** (`adfit`, host-linked, **no video** — its SDK has no fullscreen video format, so the module deliberately omits the video registration).

### Two structural patterns to know

1. **`isAvailable` gating.** An adapter registered but reporting `isAvailable == false` is treated by the orchestrator exactly like an unregistered one — the waterfall emits `WaterfallEvent.lost(.adapterNotRegistered)` and advances. This is how placeholders and unlinked SDKs degrade gracefully.

2. **`#if canImport(<SDKModule>)` guard.** FAN and AdFit do **not** publish SwiftPM packages, so their adapter files have two arms: the real implementation when the host has linked the SDK (e.g. `FBAudienceNetwork`), and a no-op placeholder (`isAvailable == false`, `load` throws) when it hasn't. This lets the whole package compile in a SwiftPM-only environment, and the real adapter activates automatically once the host links the network SDK via CocoaPods/Carthage/binary target. AdMob has no guard — it's always available via SwiftPM.

### The adapter bridge pattern (canonical: `AdMobBannerAdapter.swift`)

`load(...)` wraps the network SDK's delegate-based load in `withCheckedThrowingContinuation`. A `resumed` flag + private `resume(returning:)`/`resume(throwing:)` helpers guarantee the continuation fires exactly once. SDK creation runs on `DispatchQueue.main.async`. The SDK's delegate callbacks map to the orchestrator's closure callbacks (`onClick`, `onLeaveApp`, `onClickFinish`); load success/failure resolve the continuation. `cancel()` detaches the delegate and resumes with `CancellationError()`. Model new adapters on this file.

## Adding / filling in a network adapter

1. Create `Sources/ExelBidMediation<Network>/` with the adapter files and a module enum.
2. Add a matching `.library` product and `.target` (and the test-target dependency) in `Package.swift`.
3. For non-SwiftPM SDKs, wrap the implementation in `#if canImport(...)` with a placeholder `#else` arm.
4. Put a `// Compatible with: <SDK> <version>` + `// Last verified:` header at the top of each adapter file; bump it on SDK breaking changes (track the underlying SDK's major version).

`Tests/ExelBidMediationAdaptersTests/AdapterRegistrationTests.swift` verifies that each module registers the expected formats under the expected `networkID` and that the kit registers multiple modules. Tests call `MediationRegistry.shared.removeAllForTesting()` in setUp/tearDown — add registration assertions there for any new module.

## Notes

- Video adapters for AdMob/FAN wrap each network's **rewarded** ad format (no separate VAST video API); quartile progress is approximated. See README "Notes on video adapters".
- TargetPick (placeholder) requires `TargetPickMediationModule.configure(publisherId:mediaId:)` **before** `register(modules:)`.
- Each adapter's effective minimum iOS is the max of ExelBidSDK (iOS 13) and the network SDK; see the README adapter-inventory table.
- The README documents several Phase 4 placeholder modules (Pangle, AppLovin, DT, TNK, TargetPick) that are not yet present in `Sources/` — they are registration scaffolds to be filled in.
