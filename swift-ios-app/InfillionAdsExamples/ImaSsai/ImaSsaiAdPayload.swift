import Foundation

enum ImaSsaiAdType {
    case truex
    case idvx
    case linear
}

/// Infillion ads are detected by the IMA ad's `adSystem`, compared case-insensitively.
func classifyImaSsaiAd(adSystem: String?) -> ImaSsaiAdType {
    switch adSystem?.lowercased() {
    case "truex":
        return .truex
    case "idvx":
        return .idvx
    default:
        return .linear
    }
}

/// TrueX is interactive only as the first ad in a pod; elsewhere it plays as a normal linear ad.
/// IDVx is interactive in any position.
func canPlayImaSsaiInteractive(_ type: ImaSsaiAdType, adPosition: Int) -> Bool {
    switch type {
    case .truex:
        return adPosition == 1
    case .idvx:
        return true
    case .linear:
        return false
    }
}

/// Only a TrueX ad that earned credit (`onAdFreePod`) skips the rest of the ad break.
func shouldSkipImaSsaiAdBreak(_ type: ImaSsaiAdType, earnedCredit: Bool) -> Bool {
    type == .truex && earnedCredit
}

/// IMA exposes the VAST `<AdParameters>` JSON as `traffickingParameters`.
/// Returns nil when it is missing or not a JSON object.
func imaSsaiAdParameters(traffickingParameters: String?) -> [String: Any]? {
    guard let json = traffickingParameters?.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8),
          !json.isEmpty else {
        return nil
    }
    return (try? JSONSerialization.jsonObject(with: json)) as? [String: Any]
}

/// Stream time just before the placeholder ad ends, so the stitched stream moves on to the next ad.
func imaSsaiPlaceholderEndTime(adStartStreamTime: Double, adDuration: Double) -> Double {
    max(0, adStartStreamTime + adDuration - 0.1)
}

/// Stream time just past the current ad break, so the rest of the break is skipped.
func imaSsaiAdBreakSkipTime(adBreakEndStreamTime: Double) -> Double {
    adBreakEndStreamTime + 0.1
}
