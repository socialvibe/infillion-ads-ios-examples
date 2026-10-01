import XCTest
@testable import InfillionAdsExamples

final class ManualCsaiTests: XCTestCase {
    func testClassifiesAdSystemCaseInsensitively() {
        XCTAssertEqual(classifyManualAd(adSystem: "trueX"), .truex)
        XCTAssertEqual(classifyManualAd(adSystem: "TRUEX"), .truex)
        XCTAssertEqual(classifyManualAd(adSystem: "IDVx"), .idvx)
        XCTAssertEqual(classifyManualAd(adSystem: "idvx"), .idvx)
        XCTAssertEqual(classifyManualAd(adSystem: "GDFP"), .linear)
        XCTAssertEqual(classifyManualAd(adSystem: nil), .linear)
    }

    func testTruexIsInteractiveOnlyAsFirstAdInPod() {
        XCTAssertTrue(canPlayInteractive(.truex, adPosition: 1))
        XCTAssertFalse(canPlayInteractive(.truex, adPosition: 2))
        XCTAssertTrue(canPlayInteractive(.idvx, adPosition: 1))
        XCTAssertTrue(canPlayInteractive(.idvx, adPosition: 3))
        XCTAssertFalse(canPlayInteractive(.linear, adPosition: 1))
    }

    func testOnlyTruexCreditSkipsRemainingPod() {
        XCTAssertTrue(shouldSkipRemainingPod(.truex, earnedCredit: true))
        XCTAssertFalse(shouldSkipRemainingPod(.truex, earnedCredit: false))
        XCTAssertFalse(shouldSkipRemainingPod(.idvx, earnedCredit: true))
        XCTAssertFalse(shouldSkipRemainingPod(.linear, earnedCredit: true))
    }

    func testBundledAdBreakDecodes() throws {
        let adBreak = try ManualAdBreak.loadFromBundle()
        XCTAssertEqual(adBreak.ads.map(\.type), [.truex, .idvx, .linear, .linear])
        XCTAssertEqual(adBreak.timeOffsetSeconds, 10)
    }

    func testUserIdMacroIsReplaced() throws {
        let ad = try ManualAdBreak.loadFromBundle().ads[0]
        let url = try XCTUnwrap(ad.resolvedVastUrl(userId: "ref-app-test"))
        XCTAssertTrue(url.absoluteString.contains("network_user_id=ref-app-test"))
        XCTAssertFalse(url.absoluteString.contains("${user-id}"))
    }

    func testParsesAdParametersFromLinear() throws {
        let vast = """
        <VAST version="4.0"><Ad id="super_tag"><InLine><AdSystem>trueX</AdSystem><Creatives><Creative>
        <Linear><Duration>00:00:30</Duration>
        <AdParameters><![CDATA[{"user_id":"u1","vast_config_url":"get.truex.com/abc/vast/config"}]]></AdParameters>
        </Linear></Creative></Creatives></InLine></Ad></VAST>
        """
        let adParameters = try XCTUnwrap(ManualVastPayload.parse(vast: Data(vast.utf8)))
        XCTAssertEqual(adParameters["user_id"] as? String, "u1")
        XCTAssertEqual(adParameters["vast_config_url"] as? String, "get.truex.com/abc/vast/config")
    }

    func testEmptyVastHasNoAdParameters() {
        XCTAssertNil(ManualVastPayload.parse(vast: Data(#"<?xml version="1.0"?><VAST version="2.0"/>"#.utf8)))
    }

    func testInvalidAdParametersJsonIsRejected() {
        let vast = "<VAST><Ad><InLine><Creatives><Creative><Linear><AdParameters>not json</AdParameters></Linear></Creative></Creatives></InLine></Ad></VAST>"
        XCTAssertNil(ManualVastPayload.parse(vast: Data(vast.utf8)))
    }
}
