#import <XCTest/XCTest.h>

#import "ImaSsaiAdPayload.h"

@interface ImaSsaiTests : XCTestCase
@end

@implementation ImaSsaiTests

- (void)testClassifiesAdSystemCaseInsensitively {
    XCTAssertEqual(ClassifyImaSsaiAd(@"trueX"), ImaSsaiAdTypeTruex);
    XCTAssertEqual(ClassifyImaSsaiAd(@"idvx"), ImaSsaiAdTypeIdvx);
    XCTAssertEqual(ClassifyImaSsaiAd(@"Other"), ImaSsaiAdTypeLinear);
}

- (void)testTruexIsInteractiveOnlyAsFirstAdInPod {
    XCTAssertTrue(CanPlayImaSsaiInteractive(ImaSsaiAdTypeTruex, 1));
    XCTAssertFalse(CanPlayImaSsaiInteractive(ImaSsaiAdTypeTruex, 2));
    XCTAssertTrue(CanPlayImaSsaiInteractive(ImaSsaiAdTypeIdvx, 2));
    XCTAssertFalse(CanPlayImaSsaiInteractive(ImaSsaiAdTypeLinear, 1));
}

- (void)testOnlyTruexCreditSkipsAdBreak {
    XCTAssertTrue(ShouldSkipImaSsaiAdBreak(ImaSsaiAdTypeTruex, YES));
    XCTAssertFalse(ShouldSkipImaSsaiAdBreak(ImaSsaiAdTypeTruex, NO));
    XCTAssertFalse(ShouldSkipImaSsaiAdBreak(ImaSsaiAdTypeIdvx, YES));
}

- (void)testParsesTraffickingParameters {
    XCTAssertEqualObjects(ImaSsaiAdParameters(@"{\"user_id\":\"u1\"}")[@"user_id"], @"u1");
    XCTAssertNil(ImaSsaiAdParameters(@""));
    XCTAssertNil(ImaSsaiAdParameters(@"not json"));
}

- (void)testSeekTargets {
    XCTAssertEqualWithAccuracy(ImaSsaiPlaceholderEndTime(10, 30), 39.9, 0.0001);
    XCTAssertEqual(ImaSsaiPlaceholderEndTime(0, 0), 0);
    XCTAssertEqualWithAccuracy(ImaSsaiAdBreakSkipTime(120), 120.1, 0.0001);
}

@end
