import Foundation

// For demo purposes only. Do not use in production: read `adParameters` from the ad
// (`traffickingParameters`, see `imaSsaiAdParameters(traffickingParameters:)`).
//
// This sample takes the Infillion ads' `adParameters` from the iOS sample tags instead of from the DAI stream.
enum ImaSsaiDemoAdParameters {
    private static let truexTag = URL(string: "https://get.truex.com/22c36d3926383ba62994809a60b4649e3ced1070/vast/generic?ip=158.106.195.210")!
    private static let idvxTag = URL(string: "https://get.truex.com/132f66121635ac312e42f1eb018081d50d10fe2a/vast/idvx/generic?ip=158.106.195.210")!

    /// Fetched for every ad, so each ad gets a fresh ad session.
    static func load(for type: ImaSsaiAdType) async -> [String: Any]? {
        let url: URL
        switch type {
        case .truex:
            url = truexTag
        case .idvx:
            url = idvxTag
        case .linear:
            return nil
        }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else {
            return nil
        }
        let parser = XMLParser(data: data)
        let delegate = AdParametersParser()
        parser.delegate = delegate
        parser.parse()
        return imaSsaiAdParameters(traffickingParameters: delegate.adParameters)
    }
}

private final class AdParametersParser: NSObject, XMLParserDelegate {
    private(set) var adParameters: String?
    private var buffer: String?

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String] = [:]) {
        if elementName == "AdParameters" && adParameters == nil {
            buffer = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        buffer?.append(string)
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        buffer?.append(String(decoding: CDATABlock, as: UTF8.self))
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        if elementName == "AdParameters", let buffer {
            adParameters = buffer
            self.buffer = nil
        }
    }
}
