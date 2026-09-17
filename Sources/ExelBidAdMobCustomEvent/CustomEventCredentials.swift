// Compatible with: Google Mobile Ads SDK 12.x / 13.x

import Foundation
import ExelBidSDK
import GoogleMobileAds

/// Parses the settings the publisher entered in the AdMob console for this
/// custom event.
///
/// AdMob hands a custom event exactly one free-form string, delivered as
/// `credentials.settings["parameter"]`. We carry the ExelBid ad unit id in
/// it — the console field is labelled "Parameter" in the UI.
enum CustomEventCredentials {

    /// Key AdMob uses for the custom event's single parameter field.
    static let parameterKey = "parameter"

    /// Extracts the ExelBid ad unit id, or throws the error to hand back to
    /// the Google Mobile Ads SDK.
    static func adUnitId(from configuration: MediationAdConfiguration) throws -> String {
        let raw = configuration.credentials.settings[parameterKey] as? String
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else {
            throw CustomEventError.missingAdUnitId
        }
        return trimmed
    }

    /// Per-request targeting the host registered through
    /// `Request.register(ExelBidAdMobExtras())`. AdMob's mediation
    /// configuration carries no keyword / COPPA / demographics fields of its
    /// own, so the extras object is the only channel for them.
    static func options(from configuration: MediationAdConfiguration) -> EBAdOptions {
        (configuration.extras as? ExelBidAdMobExtras)?.options ?? EBAdOptions()
    }
}

/// Errors originating in the adapter itself (as opposed to `EBAdError`s
/// surfaced by the ExelBid SDK, which are forwarded unchanged).
enum CustomEventError {

    static let domain = "com.exelbid.admob.customevent"

    enum Code: Int {
        case missingAdUnitId = 1001
        case adapterDeallocated = 1002
    }

    static let missingAdUnitId = NSError(
        domain: domain,
        code: Code.missingAdUnitId.rawValue,
        userInfo: [
            NSLocalizedDescriptionKey:
                "ExelBid ad unit id is missing. Set it in the AdMob console's "
                + "custom event 'Parameter' field."
        ]
    )

    static let adapterDeallocated = NSError(
        domain: domain,
        code: Code.adapterDeallocated.rawValue,
        userInfo: [NSLocalizedDescriptionKey: "The adapter was released before the ad loaded."]
    )
}
