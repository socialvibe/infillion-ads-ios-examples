import Foundation

/// Fetches an Infillion VAST tag and returns the `adParameters` JSON from `<Linear><AdParameters>`.
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

    /// Returns nil when the VAST has no ad or its `<AdParameters>` isn't a JSON object.
    static func parse(vast: Data) -> [String: Any]? {
        let delegate = AdParametersParser()
        let parser = XMLParser(data: vast)
        parser.delegate = delegate
        parser.parse()
        guard let text = delegate.adParameters?.trimmingCharacters(in: .whitespacesAndNewlines),
            let json = text.data(using: .utf8)
        else {
            return nil
        }
        return (try? JSONSerialization.jsonObject(with: json)) as? [String: Any]
    }
}

private final class AdParametersParser: NSObject, XMLParserDelegate {
    private(set) var adParameters: String?
    private var inLinear = false
    private var buffer: String?

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String] = [:]
    ) {
        if elementName == "Linear" {
            inLinear = true
        } else if inLinear && elementName == "AdParameters" && adParameters == nil {
            buffer = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        buffer?.append(string)
    }

    func parser(_ parser: XMLParser, foundCDATA cdataBlock: Data) {
        buffer?.append(String(decoding: cdataBlock, as: UTF8.self))
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        if elementName == "AdParameters", let buffer {
            adParameters = buffer
            self.buffer = nil
        } else if elementName == "Linear" {
            inLinear = false
        }
    }
}
