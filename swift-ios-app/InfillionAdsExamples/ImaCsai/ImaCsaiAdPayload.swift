import Foundation

enum ImaCsaiAdType {
    case truex
    case idvx
    case linear
}

/// Infillion ads are detected by the IMA ad's `adSystem`, compared case-insensitively.
func classifyImaCsaiAd(adSystem: String?) -> ImaCsaiAdType {
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
func canPlayImaCsaiInteractive(_ type: ImaCsaiAdType, adPosition: Int) -> Bool {
    switch type {
    case .truex:
        return adPosition == 1
    case .idvx:
        return true
    case .linear:
        return false
    }
}

/// Only a TrueX ad that earned credit (`onAdFreePod`) skips the rest of the pod.
func shouldDiscardImaCsaiAdBreak(_ type: ImaCsaiAdType, earnedCredit: Bool) -> Bool {
    type == .truex && earnedCredit
}

/// Infillion tags deliver `adParameters` as a `truex` companion (companion tag) or as `<AdParameters>` (generic tag).
/// IMA exposes them as `ad.companionAds` and `ad.traffickingParameters`; the companion is checked first.
/// Returns nil when neither holds a JSON object.
func imaCsaiAdParameters(
    companions: [(apiFramework: String?, resourceValue: String?)],
    traffickingParameters: String?
) -> [String: Any]? {
    for companion in companions where companion.apiFramework?.lowercased() == "truex" {
        if let resource = companion.resourceValue, let adParameters = imaCsaiCompanionAdParameters(resource) {
            return adParameters
        }
    }
    return imaCsaiJsonObject(traffickingParameters)
}

/// Decodes a `data:application/json;base64,...` URL. Any other resource is read as plain JSON.
func imaCsaiCompanionAdParameters(_ resource: String) -> [String: Any]? {
    let trimmed = resource.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.lowercased().hasPrefix("data:") else {
        return imaCsaiJsonObject(trimmed)
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

private func imaCsaiJsonObject(_ text: String?) -> [String: Any]? {
    guard let json = text?.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8), !json.isEmpty else {
        return nil
    }
    return (try? JSONSerialization.jsonObject(with: json)) as? [String: Any]
}
