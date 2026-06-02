Pod::Spec.new do |s|
  s.name             = 'ExelBid_Mediation_Adapter'
  # Source pod: the Swift import name defaults to `s.name`. Override it so
  # hosts `import ExelBidMediationAdapter` regardless of the pod name.
  s.module_name      = 'ExelBidMediationAdapter'
  s.version          = '1.0.0'
  s.summary          = 'Third-party network adapters for ExelBid iOS SDK v3 mediation.'
  s.description      = <<-DESC
    Thin bridge adapters between each ad network's iOS SDK and the ExelBid
    mediation contract. Each network is exposed as a CocoaPods subspec so
    host apps integrate only the networks they actually use, e.g.
    `pod 'ExelBid_Mediation_Adapter/AdMob'`. The mediation core (orchestrator,
    protocols, registry) ships with the `ExelBid_iOS_Swift` pod.
  DESC
  s.homepage         = 'https://github.com/onnuridmc/ExelBid_iOS_Mediation_Adapter'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { "ExelBid" => "dev@motiv-i.com" }
  s.source           = {
    :git => 'https://github.com/onnuridmc/ExelBid_iOS_Mediation_Adapter.git',
    :tag => s.version.to_s
  }

  # Base deployment target. AdMob (GoogleMobileAds 12.x) and FAN effectively
  # require iOS 14 — those subspecs raise it below; AdFit stays at 13.
  s.ios.deployment_target = '13.0'
  s.swift_version         = '5.9'
  s.static_framework      = true   # required: GoogleMobileAds ships as a static framework

  # Mediation core: protocols, registry, orchestrator. Every adapter needs it.
  # Match the SwiftPM `from: "3.0.0"` constraint (>= 3.0.0, < 4.0.0).
  s.dependency 'ExelBid_iOS_Swift', '~> 3.0'

  # No default_subspec on purpose: integrating bare
  # `pod 'ExelBid_Mediation_Adapter'` would pull every network SDK.
  # Hosts must pick subspecs explicitly.

  # --- AdMob (Google Mobile Ads) — all 4 formats, SDK on CocoaPods --------
  s.subspec 'AdMob' do |sp|
    sp.ios.deployment_target = '14.0'
    sp.source_files = 'Sources/ExelBidMediationAdMob/**/*.swift'
    sp.dependency 'Google-Mobile-Ads-SDK', '~> 12.0'
  end

  # --- Facebook Audience Network — guarded by #if canImport(FBAudienceNetwork)
  s.subspec 'FAN' do |sp|
    sp.ios.deployment_target = '14.0'
    sp.source_files = 'Sources/ExelBidMediationFAN/**/*.swift'
    sp.dependency 'FBAudienceNetwork', '~> 6.0'
  end

  # --- Kakao AdFit — guarded by #if canImport(AdFitSDK), no video format ---
  s.subspec 'AdFit' do |sp|
    sp.ios.deployment_target = '13.0'
    sp.source_files = 'Sources/ExelBidMediationAdFit/**/*.swift'
    sp.dependency 'AdFitSDK', '~> 3.0'
  end
end
