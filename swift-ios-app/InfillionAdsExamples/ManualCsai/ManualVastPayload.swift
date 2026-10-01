import Foundation

/// Fetches an Infillion VAST tag and returns its `adParameters` JSON.
///
/// Infillion tags deliver `adParameters` in one of two formats:
/// - Companion tag (`/vast/companion`, `/vast/idvx/companion`): a base64 JSON `data:` URL in
///   `<Companion apiFramework="truex"><StaticResource creativeType="application/json">`.
/// - Generic tag (`/vast/generic`, `/vast/idvx/generic`): the JSON in `<Linear><AdParameters>`.
///
/// The companion is checked first, then `<AdParameters>`.
enum ManualVastPayload {
    static func load(from url: URL) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let adParameters = parse(vast: data) else {
            throw URLError(.cannotParseResponse)
        }
        return adParameters
    }

    /// Returns nil when the VAST has no ad or neither format holds a JSON object.
    static func parse(vast: Data) -> [String: Any]? {
        let delegate = AdParametersParser()
        let parser = XMLParser(data: vast)
        parser.delegate = delegate
        parser.parse()
        if let companion = delegate.companionResource, let adParameters = companionAdParameters(companion) {
            return adParameters
        }
        if let text = delegate.adParameters {
            return jsonObject(text)
        }
        return nil
    }

    /// Decodes a `data:application/json;base64,...` URL. A resource without a comma is read as plain JSON.
    static func companionAdParameters(_ resource: String) -> [String: Any]? {
        let compact = resource.filter { !$0.isWhitespace }
        guard let comma = compact.firstIndex(of: ",") else {
            return jsonObject(compact)
        }
        guard let decoded = Data(base64Encoded: String(compact[compact.index(after: comma)...])) else {
            return nil
        }
        return (try? JSONSerialization.jsonObject(with: decoded)) as? [String: Any]
    }

    private static func jsonObject(_ text: String) -> [String: Any]? {
        guard let json = text.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8) else {
            return nil
        }
        return (try? JSONSerialization.jsonObject(with: json)) as? [String: Any]
    }
}

private final class AdParametersParser: NSObject, XMLParserDelegate {
    private(set) var adParameters: String?
    private(set) var companionResource: String?
    private var inLinear = false
    private var inTruexCompanion = false
    private var adParametersBuffer: String?
    private var companionBuffer: String?

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String] = [:]
    ) {
        switch elementName {
        case "Linear":
            inLinear = true
        case "AdParameters" where inLinear && adParameters == nil:
            adParametersBuffer = ""
        case "Companion":
            inTruexCompanion = attributes["apiFramework"]?.lowercased() == "truex"
        case "StaticResource" where inTruexCompanion && companionResource == nil:
            if attributes["creativeType"]?.lowercased() == "application/json" {
                companionBuffer = ""
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        adParametersBuffer?.append(string)
        companionBuffer?.append(string)
    }

    func parser(_ parser: XMLParser, foundCDATA cdataBlock: Data) {
        let text = String(decoding: cdataBlock, as: UTF8.self)
        adParametersBuffer?.append(text)
        companionBuffer?.append(text)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        switch elementName {
        case "Linear":
            inLinear = false
        case "AdParameters":
            if let adParametersBuffer {
                adParameters = adParametersBuffer
                self.adParametersBuffer = nil
            }
        case "Companion":
            inTruexCompanion = false
        case "StaticResource":
            if let companionBuffer {
                companionResource = companionBuffer
                self.companionBuffer = nil
            }
        default:
            break
        }
    }
}
