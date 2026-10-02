#import <XCTest/XCTest.h>

#import "ImaSsaiAdPayload.h"

/// Stands in for `IMACompanionAd`, which can't be created outside IMA.
@interface FakeImaSsaiCompanion : NSObject

@property(nonatomic, copy) NSString *APIFramework;
@property(nonatomic, copy) NSString *resourceValue;

@end

@implementation FakeImaSsaiCompanion
@end

static NSArray<IMACompanionAd *> *ImaSsaiCompanions(NSArray<NSArray<NSString *> *> *values) {
    NSMutableArray *companions = [NSMutableArray array];
    for (NSArray<NSString *> *value in values) {
        FakeImaSsaiCompanion *companion = [[FakeImaSsaiCompanion alloc] init];
        companion.APIFramework = value[0];
        companion.resourceValue = value[1];
        [companions addObject:companion];
    }
    return (NSArray<IMACompanionAd *> *)companions;
}

// `{"user_id":"u1"}` as a base64 `data:` URL, wrapped like the ad server does.
static NSString *const kImaSsaiCompanionDataUrl = @"data:application/json;base64,eyJ1c2Vy\n        X2lkIjoidTEifQ==";

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
    XCTAssertEqualObjects(ImaSsaiAdParameters(nil, @"{\"user_id\":\"u1\"}")[@"user_id"], @"u1");
    XCTAssertNil(ImaSsaiAdParameters(nil, @""));
    XCTAssertNil(ImaSsaiAdParameters(nil, @"not json"));
}

- (void)testSeekTargets {
    XCTAssertEqualWithAccuracy(ImaSsaiPlaceholderEndTime(10, 30), 39.9, 0.0001);
    XCTAssertEqual(ImaSsaiPlaceholderEndTime(0, 0), 0);
    XCTAssertEqualWithAccuracy(ImaSsaiAdBreakSkipTime(120), 120.1, 0.0001);
}

- (void)testReadsAdParametersFromTruexCompanion {
    NSDictionary *adParameters =
        ImaSsaiAdParameters(ImaSsaiCompanions(@[ @[ @"truex", kImaSsaiCompanionDataUrl ] ]), @"");
    XCTAssertEqualObjects(adParameters[@"user_id"], @"u1");
}

- (void)testCompanionWinsOverTraffickingParameters {
    NSDictionary *adParameters = ImaSsaiAdParameters(ImaSsaiCompanions(@[ @[ @"TrueX", kImaSsaiCompanionDataUrl ] ]),
                                                     @"{\"user_id\":\"trafficking\"}");
    XCTAssertEqualObjects(adParameters[@"user_id"], @"u1");
}

- (void)testFallsBackToTraffickingParameters {
    NSArray<IMACompanionAd *> *companions = ImaSsaiCompanions(@[
        @[ @"VPAID", kImaSsaiCompanionDataUrl ],
        @[ @"truex", @"data:application/json;base64,!!!" ],
    ]);
    NSDictionary *adParameters = ImaSsaiAdParameters(companions, @"{\"user_id\":\"trafficking\"}");
    XCTAssertEqualObjects(adParameters[@"user_id"], @"trafficking");
}

- (void)testKeepsPlainJsonCompanionResourceUnchanged {
    NSDictionary *adParameters =
        ImaSsaiCompanionAdParameters(@"  {\"user_id\":\"plain\",\"user_name\":\"first last\"}  ");
    XCTAssertEqualObjects(adParameters[@"user_name"], @"first last");
}

@end
