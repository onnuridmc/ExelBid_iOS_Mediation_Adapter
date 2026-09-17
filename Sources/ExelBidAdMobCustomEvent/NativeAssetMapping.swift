// Compatible with: Google Mobile Ads SDK 12.x / 13.x

import UIKit
import ExelBidSDK
import GoogleMobileAds

/// Maps an ExelBid native payload onto the fields `MediatedUnifiedNativeAd`
/// exposes. Pure value logic, kept apart from the ad object so it can be
/// tested from a decoded `EBNativeAdModel`.
struct NativeAssetMapping {

    /// Phase 1 serves image creatives only, so the VAST `video` asset is not
    /// requested.
    static let requestedAssets: Set<EBNativeAsset> = Set(EBNativeAsset.allCases).subtracting([.video])

    let headline: String?
    let body: String?
    let callToAction: String?
    let price: String?
    let advertiser: String?
    let starRating: NSDecimalNumber?
    let iconURL: URL?
    let mainURL: URL?
    /// ExelBid assets with no dedicated `MediatedUnifiedNativeAd` property,
    /// keyed by the server's asset names.
    let extraAssets: [String: Any]?

    init(model: EBNativeAdModel) {
        headline = model.title
        body = model.desc
        callToAction = model.ctatext
        price = model.price
        advertiser = model.sponsored
        starRating = Self.starRating(from: model.rating)
        iconURL = model.icon.flatMap(URL.init(string:))
        mainURL = model.main.flatMap(URL.init(string:))

        let extras: [String: String?] = [
            "desc2": model.desc2,
            "displayurl": model.displayurl,
            "phone": model.phone,
            "address": model.address,
            "logo": model.logo,
            "likes": model.likes,
            "downloads": model.downloads,
            "saleprice": model.saleprice
        ]
        let present = extras.compactMapValues { $0 }
        extraAssets = present.isEmpty ? nil : present
    }

    /// GMA expects a rating in 0...5. Anything unparseable or out of range is
    /// dropped rather than passed on.
    static func starRating(from string: String?) -> NSDecimalNumber? {
        guard let string = string?.trimmingCharacters(in: .whitespaces), !string.isEmpty else {
            return nil
        }
        let number = NSDecimalNumber(string: string, locale: Locale(identifier: "en_US_POSIX"))
        guard number != .notANumber,
              number.compare(NSDecimalNumber.zero) != .orderedAscending,
              number.compare(NSDecimalNumber(value: 5)) != .orderedDescending
        else { return nil }
        return number
    }

    /// With default loader options GMA expects image content already loaded
    /// (`MediaView` shows `images.first` and is empty when image loading is
    /// disabled). Only when the host opted out do we pass URLs alone.
    static func isImageLoadingDisabled(_ options: [GADAdLoaderOptions]) -> Bool {
        options.contains { ($0 as? NativeAdImageAdLoaderOptions)?.isImageLoadingDisabled == true }
    }

    /// Downloads an image, or returns nil on any failure. A missing image
    /// does not fail the ad.
    static func fetchImage(at url: URL?, session: URLSession = .shared) async -> UIImage? {
        guard let url = url,
              let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true
        else { return nil }
        return UIImage(data: data)
    }
}
