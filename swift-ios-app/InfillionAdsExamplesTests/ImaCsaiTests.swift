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
        let adParameters = try XCTUnwrap(imaCsaiAdParameters(traffickingParameters: #" {"user_id":"u1","vast_config_url":"get.truex.com/abc/vast/config"} "#))
        XCTAssertEqual(adParameters["user_id"] as? String, "u1")
    }

    func testRejectsMissingOrInvalidTraffickingParameters() {
        XCTAssertNil(imaCsaiAdParameters(traffickingParameters: nil))
        XCTAssertNil(imaCsaiAdParameters(traffickingParameters: ""))
        XCTAssertNil(imaCsaiAdParameters(traffickingParameters: "not json"))
        XCTAssertNil(imaCsaiAdParameters(traffickingParameters: "[1, 2]"))
    }

    func testBundledVmapUsesIosPlacements() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "ima_csai_vmap", withExtension: "xml"))
        let vmap = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(vmap.contains("22c36d3926383ba62994809a60b4649e3ced1070/vast/generic"))
        XCTAssertTrue(vmap.contains("132f66121635ac312e42f1eb018081d50d10fe2a/vast/idvx/generic"))
    }
}
