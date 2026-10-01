import Foundation

enum ManualAdType {
    case truex
    case idvx
    case linear
}

/// Infillion ads are detected by their VAST `<AdSystem>`, compared case-insensitively.
func classifyManualAd(adSystem: String?) -> ManualAdType {
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
func canPlayInteractive(_ type: ManualAdType, adPosition: Int) -> Bool {
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
func shouldSkipRemainingPod(_ type: ManualAdType, earnedCredit: Bool) -> Bool {
    type == .truex && earnedCredit
}

struct ManualAd: Decodable {
    let id: String
    let adSystem: String
    let mediaUrl: URL
    let vastUrl: String?
    let durationSeconds: Double

    var type: ManualAdType {
        classifyManualAd(adSystem: adSystem)
    }

    /// The sample tags carry a `${user-id}` macro that a real ad server would fill in.
    func resolvedVastUrl(userId: String) -> URL? {
        guard let vastUrl else {
            return nil
        }
        return URL(string: vastUrl.replacingOccurrences(of: "${user-id}", with: userId))
    }
}

struct ManualAdBreak: Decodable {
    let breakId: String
    let timeOffsetSeconds: Double
    let ads: [ManualAd]

    static func loadFromBundle(named name: String = "manual_ad_break") throws -> ManualAdBreak {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(ManualAdBreak.self, from: Data(contentsOf: url))
    }
}
