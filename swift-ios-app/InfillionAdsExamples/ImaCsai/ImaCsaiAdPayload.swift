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

/// IMA exposes the VAST `<AdParameters>` JSON as `traffickingParameters`.
/// Returns nil when it is missing or not a JSON object.
func imaCsaiAdParameters(traffickingParameters: String?) -> [String: Any]? {
    guard let json = traffickingParameters?.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8),
          !json.isEmpty else {
        return nil
    }
    return (try? JSONSerialization.jsonObject(with: json)) as? [String: Any]
}
