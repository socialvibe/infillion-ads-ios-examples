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

/// Infillion tags deliver `adParameters` as a `truex` companion (companion tag) or as `<AdParameters>` (generic tag).
/// IMA exposes them as `ad.companionAds` and `ad.traffickingParameters`; the companion is checked first.
/// Returns nil when neither holds a JSON object.
func imaSsaiAdParameters(
    companions: [(apiFramework: String?, resourceValue: String?)],
    traffickingParameters: String?
) -> [String: Any]? {
    for companion in companions where companion.apiFramework?.lowercased() == "truex" {
        if let resource = companion.resourceValue, let adParameters = imaSsaiCompanionAdParameters(resource) {
            return adParameters
        }
    }
    return imaSsaiJsonObject(traffickingParameters)
}

/// Decodes a `data:application/json;base64,...` URL. Any other resource is read as plain JSON.
func imaSsaiCompanionAdParameters(_ resource: String) -> [String: Any]? {
    let trimmed = resource.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.lowercased().hasPrefix("data:") else {
        return imaSsaiJsonObject(trimmed)
    }
    // The ad server wraps the base64 payload across lines, so whitespace is removed before decoding.
    let compact = trimmed.filter { !$0.isWhitespace }
    guard let comma = compact.firstIndex(of: ","),
        let decoded = Data(base64Encoded: String(compact[compact.index(after: comma)...]))
    else {
        return nil
    }
    return (try? JSONSerialization.jsonObject(with: decoded)) as? [String: Any]
}

private func imaSsaiJsonObject(_ text: String?) -> [String: Any]? {
    guard let json = text?.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8), !json.isEmpty else {
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
