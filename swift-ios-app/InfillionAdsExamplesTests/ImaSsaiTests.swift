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
        XCTAssertEqual(imaSsaiAdParameters(traffickingParameters: #"{"user_id":"u1"}"#)?["user_id"] as? String, "u1")
        XCTAssertNil(imaSsaiAdParameters(traffickingParameters: ""))
        XCTAssertNil(imaSsaiAdParameters(traffickingParameters: "not json"))
    }

    func testSeekTargets() {
        XCTAssertEqual(imaSsaiPlaceholderEndTime(adStartStreamTime: 10, adDuration: 30), 39.9, accuracy: 0.0001)
        XCTAssertEqual(imaSsaiPlaceholderEndTime(adStartStreamTime: 0, adDuration: 0), 0)
        XCTAssertEqual(imaSsaiAdBreakSkipTime(adBreakEndStreamTime: 120), 120.1, accuracy: 0.0001)
    }
}
