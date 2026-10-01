#import <XCTest/XCTest.h>

#import "ImaCsaiAdPayload.h"

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
        ImaCsaiAdParameters(@" {\"user_id\":\"u1\",\"vast_config_url\":\"get.truex.com/abc/vast/config\"} ");
    XCTAssertEqualObjects(adParameters[@"user_id"], @"u1");
}

- (void)testRejectsMissingOrInvalidTraffickingParameters {
    XCTAssertNil(ImaCsaiAdParameters(nil));
    XCTAssertNil(ImaCsaiAdParameters(@""));
    XCTAssertNil(ImaCsaiAdParameters(@"not json"));
    XCTAssertNil(ImaCsaiAdParameters(@"[1, 2]"));
}

- (void)testBundledVmapUsesIosPlacements {
    NSURL *url = [NSBundle.mainBundle URLForResource:@"ima_csai_vmap" withExtension:@"xml"];
    NSString *vmap = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil];
    XCTAssertTrue([vmap containsString:@"22c36d3926383ba62994809a60b4649e3ced1070/vast/generic"]);
    XCTAssertTrue([vmap containsString:@"132f66121635ac312e42f1eb018081d50d10fe2a/vast/idvx/generic"]);
}

@end
