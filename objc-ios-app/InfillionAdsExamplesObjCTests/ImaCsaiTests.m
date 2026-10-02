#import <XCTest/XCTest.h>

#import "ImaCsaiAdPayload.h"

/// Stands in for `IMACompanionAd`, which can't be created outside IMA.
@interface FakeImaCsaiCompanion : NSObject

@property(nonatomic, copy) NSString *APIFramework;
@property(nonatomic, copy) NSString *resourceValue;

@end

@implementation FakeImaCsaiCompanion
@end

static NSArray<IMACompanionAd *> *ImaCsaiCompanions(NSArray<NSArray<NSString *> *> *values) {
    NSMutableArray *companions = [NSMutableArray array];
    for (NSArray<NSString *> *value in values) {
        FakeImaCsaiCompanion *companion = [[FakeImaCsaiCompanion alloc] init];
        companion.APIFramework = value[0];
        companion.resourceValue = value[1];
        [companions addObject:companion];
    }
    return (NSArray<IMACompanionAd *> *)companions;
}

// `{"user_id":"u1"}` as a base64 `data:` URL, wrapped like the ad server does.
static NSString *const kImaCsaiCompanionDataUrl = @"data:application/json;base64,eyJ1c2Vy\n        X2lkIjoidTEifQ==";

@interface ImaCsaiTests : XCTestCase
@end

@implementation ImaCsaiTests

- (void)testClassifiesAdSystemCaseInsensitively {
    XCTAssertEqual(ClassifyImaCsaiAd(@"trueX"), ImaCsaiAdTypeTruex);
    XCTAssertEqual(ClassifyImaCsaiAd(@"IDVX"), ImaCsaiAdTypeIdvx);
    XCTAssertEqual(ClassifyImaCsaiAd(@"GDFP"), ImaCsaiAdTypeLinear);
    XCTAssertEqual(ClassifyImaCsaiAd(nil), ImaCsaiAdTypeLinear);
}

- (void)testTruexIsInteractiveOnlyAsFirstAdInPod {
    XCTAssertTrue(CanPlayImaCsaiInteractive(ImaCsaiAdTypeTruex, 1));
    XCTAssertFalse(CanPlayImaCsaiInteractive(ImaCsaiAdTypeTruex, 2));
    XCTAssertTrue(CanPlayImaCsaiInteractive(ImaCsaiAdTypeIdvx, 2));
    XCTAssertFalse(CanPlayImaCsaiInteractive(ImaCsaiAdTypeLinear, 1));
}

- (void)testOnlyTruexCreditDiscardsAdBreak {
    XCTAssertTrue(ShouldDiscardImaCsaiAdBreak(ImaCsaiAdTypeTruex, YES));
    XCTAssertFalse(ShouldDiscardImaCsaiAdBreak(ImaCsaiAdTypeTruex, NO));
    XCTAssertFalse(ShouldDiscardImaCsaiAdBreak(ImaCsaiAdTypeIdvx, YES));
}

- (void)testParsesTraffickingParameters {
    NSDictionary *adParameters =
        ImaCsaiAdParameters(nil, @" {\"user_id\":\"u1\",\"vast_config_url\":\"get.truex.com/abc/vast/config\"} ");
    XCTAssertEqualObjects(adParameters[@"user_id"], @"u1");
}

- (void)testRejectsMissingOrInvalidTraffickingParameters {
    XCTAssertNil(ImaCsaiAdParameters(nil, nil));
    XCTAssertNil(ImaCsaiAdParameters(nil, @""));
    XCTAssertNil(ImaCsaiAdParameters(nil, @"not json"));
    XCTAssertNil(ImaCsaiAdParameters(nil, @"[1, 2]"));
}

- (void)testBundledVmapUsesIosPlacements {
    NSURL *url = [NSBundle.mainBundle URLForResource:@"ima_csai_vmap" withExtension:@"xml"];
    NSString *vmap = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil];
    XCTAssertTrue([vmap containsString:@"22c36d3926383ba62994809a60b4649e3ced1070/vast/generic"]);
    XCTAssertTrue([vmap containsString:@"132f66121635ac312e42f1eb018081d50d10fe2a/vast/idvx/generic"]);
}

- (void)testReadsAdParametersFromTruexCompanion {
    NSDictionary *adParameters =
        ImaCsaiAdParameters(ImaCsaiCompanions(@[ @[ @"truex", kImaCsaiCompanionDataUrl ] ]), @"");
    XCTAssertEqualObjects(adParameters[@"user_id"], @"u1");
}

- (void)testCompanionWinsOverTraffickingParameters {
    NSDictionary *adParameters = ImaCsaiAdParameters(ImaCsaiCompanions(@[ @[ @"TrueX", kImaCsaiCompanionDataUrl ] ]),
                                                     @"{\"user_id\":\"trafficking\"}");
    XCTAssertEqualObjects(adParameters[@"user_id"], @"u1");
}

- (void)testFallsBackToTraffickingParameters {
    NSArray<IMACompanionAd *> *companions = ImaCsaiCompanions(@[
        @[ @"VPAID", kImaCsaiCompanionDataUrl ],
        @[ @"truex", @"data:application/json;base64,!!!" ],
    ]);
    NSDictionary *adParameters = ImaCsaiAdParameters(companions, @"{\"user_id\":\"trafficking\"}");
    XCTAssertEqualObjects(adParameters[@"user_id"], @"trafficking");
}

- (void)testKeepsPlainJsonCompanionResourceUnchanged {
    NSDictionary *adParameters =
        ImaCsaiCompanionAdParameters(@"  {\"user_id\":\"plain\",\"user_name\":\"first last\"}  ");
    XCTAssertEqualObjects(adParameters[@"user_name"], @"first last");
}

@end
