import XCTest

@testable import InfillionAdsExamples

final class ImaCsaiTests: XCTestCase {
    func testClassifiesAdSystemCaseInsensitively() {
        XCTAssertEqual(classifyImaCsaiAd(adSystem: "trueX"), .truex)
        XCTAssertEqual(classifyImaCsaiAd(adSystem: "IDVX"), .idvx)
        XCTAssertEqual(classifyImaCsaiAd(adSystem: "GDFP"), .linear)
        XCTAssertEqual(classifyImaCsaiAd(adSystem: nil), .linear)
    }

    func testTruexIsInteractiveOnlyAsFirstAdInPod() {
        XCTAssertTrue(canPlayImaCsaiInteractive(.truex, adPosition: 1))
        XCTAssertFalse(canPlayImaCsaiInteractive(.truex, adPosition: 2))
        XCTAssertTrue(canPlayImaCsaiInteractive(.idvx, adPosition: 2))
        XCTAssertFalse(canPlayImaCsaiInteractive(.linear, adPosition: 1))
    }

    func testOnlyTruexCreditDiscardsAdBreak() {
        XCTAssertTrue(shouldDiscardImaCsaiAdBreak(.truex, earnedCredit: true))
        XCTAssertFalse(shouldDiscardImaCsaiAdBreak(.truex, earnedCredit: false))
        XCTAssertFalse(shouldDiscardImaCsaiAdBreak(.idvx, earnedCredit: true))
    }

    func testParsesTraffickingParameters() throws {
        let adParameters = try XCTUnwrap(
            imaCsaiAdParameters(
                companions: [],
                traffickingParameters: #" {"user_id":"u1","vast_config_url":"get.truex.com/abc/vast/config"} "#
            )
        )
        XCTAssertEqual(adParameters["user_id"] as? String, "u1")
    }

    func testRejectsMissingOrInvalidTraffickingParameters() {
        XCTAssertNil(imaCsaiAdParameters(companions: [], traffickingParameters: nil))
        XCTAssertNil(imaCsaiAdParameters(companions: [], traffickingParameters: ""))
        XCTAssertNil(imaCsaiAdParameters(companions: [], traffickingParameters: "not json"))
        XCTAssertNil(imaCsaiAdParameters(companions: [], traffickingParameters: "[1, 2]"))
    }

    func testBundledVmapUsesIosPlacements() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "ima_csai_vmap", withExtension: "xml"))
        let vmap = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(vmap.contains("22c36d3926383ba62994809a60b4649e3ced1070/vast/generic"))
        XCTAssertTrue(vmap.contains("132f66121635ac312e42f1eb018081d50d10fe2a/vast/idvx/generic"))
    }

    // `{"user_id":"u1"}` as a base64 `data:` URL, wrapped like the ad server does.
    private static let companionDataUrl = """
        data:application/json;base64,eyJ1c2Vy
        X2lkIjoidTEifQ==
        """

    func testReadsAdParametersFromTruexCompanion() {
        let adParameters = imaCsaiAdParameters(
            companions: [("truex", Self.companionDataUrl)],
            traffickingParameters: ""
        )
        XCTAssertEqual(adParameters?["user_id"] as? String, "u1")
    }

    func testCompanionWinsOverTraffickingParameters() {
        let adParameters = imaCsaiAdParameters(
            companions: [("TrueX", Self.companionDataUrl)],
            traffickingParameters: #"{"user_id":"trafficking"}"#
        )
        XCTAssertEqual(adParameters?["user_id"] as? String, "u1")
    }

    func testFallsBackToTraffickingParameters() {
        let adParameters = imaCsaiAdParameters(
            companions: [("VPAID", Self.companionDataUrl), ("truex", "data:application/json;base64,!!!")],
            traffickingParameters: #"{"user_id":"trafficking"}"#
        )
        XCTAssertEqual(adParameters?["user_id"] as? String, "trafficking")
    }

    func testKeepsPlainJsonCompanionResourceUnchanged() {
        let adParameters = imaCsaiCompanionAdParameters(#"  {"user_id":"plain","user_name":"first last"}  "#)
        XCTAssertEqual(adParameters?["user_name"] as? String, "first last")
    }
}
