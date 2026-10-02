import XCTest

@testable import InfillionAdsExamples

final class ImaSsaiTests: XCTestCase {
    func testClassifiesAdSystemCaseInsensitively() {
        XCTAssertEqual(classifyImaSsaiAd(adSystem: "trueX"), .truex)
        XCTAssertEqual(classifyImaSsaiAd(adSystem: "idvx"), .idvx)
        XCTAssertEqual(classifyImaSsaiAd(adSystem: "Other"), .linear)
    }

    func testTruexIsInteractiveOnlyAsFirstAdInPod() {
        XCTAssertTrue(canPlayImaSsaiInteractive(.truex, adPosition: 1))
        XCTAssertFalse(canPlayImaSsaiInteractive(.truex, adPosition: 2))
        XCTAssertTrue(canPlayImaSsaiInteractive(.idvx, adPosition: 2))
        XCTAssertFalse(canPlayImaSsaiInteractive(.linear, adPosition: 1))
    }

    func testOnlyTruexCreditSkipsAdBreak() {
        XCTAssertTrue(shouldSkipImaSsaiAdBreak(.truex, earnedCredit: true))
        XCTAssertFalse(shouldSkipImaSsaiAdBreak(.truex, earnedCredit: false))
        XCTAssertFalse(shouldSkipImaSsaiAdBreak(.idvx, earnedCredit: true))
    }

    func testParsesTraffickingParameters() {
        XCTAssertEqual(
            imaSsaiAdParameters(companions: [], traffickingParameters: #"{"user_id":"u1"}"#)?["user_id"] as? String,
            "u1"
        )
        XCTAssertNil(imaSsaiAdParameters(companions: [], traffickingParameters: ""))
        XCTAssertNil(imaSsaiAdParameters(companions: [], traffickingParameters: "not json"))
    }

    func testSeekTargets() {
        XCTAssertEqual(imaSsaiPlaceholderEndTime(adStartStreamTime: 10, adDuration: 30), 39.9, accuracy: 0.0001)
        XCTAssertEqual(imaSsaiPlaceholderEndTime(adStartStreamTime: 0, adDuration: 0), 0)
        XCTAssertEqual(imaSsaiAdBreakSkipTime(adBreakEndStreamTime: 120), 120.1, accuracy: 0.0001)
    }

    // `{"user_id":"u1"}` as a base64 `data:` URL, wrapped like the ad server does.
    private static let companionDataUrl = """
        data:application/json;base64,eyJ1c2Vy
        X2lkIjoidTEifQ==
        """

    func testReadsAdParametersFromTruexCompanion() {
        let adParameters = imaSsaiAdParameters(
            companions: [("truex", Self.companionDataUrl)],
            traffickingParameters: ""
        )
        XCTAssertEqual(adParameters?["user_id"] as? String, "u1")
    }

    func testCompanionWinsOverTraffickingParameters() {
        let adParameters = imaSsaiAdParameters(
            companions: [("TrueX", Self.companionDataUrl)],
            traffickingParameters: #"{"user_id":"trafficking"}"#
        )
        XCTAssertEqual(adParameters?["user_id"] as? String, "u1")
    }

    func testFallsBackToTraffickingParameters() {
        let adParameters = imaSsaiAdParameters(
            companions: [("VPAID", Self.companionDataUrl), ("truex", "data:application/json;base64,!!!")],
            traffickingParameters: #"{"user_id":"trafficking"}"#
        )
        XCTAssertEqual(adParameters?["user_id"] as? String, "trafficking")
    }

    func testKeepsPlainJsonCompanionResourceUnchanged() {
        let adParameters = imaSsaiCompanionAdParameters(#"  {"user_id":"plain","user_name":"first last"}  "#)
        XCTAssertEqual(adParameters?["user_name"] as? String, "first last")
    }
}
