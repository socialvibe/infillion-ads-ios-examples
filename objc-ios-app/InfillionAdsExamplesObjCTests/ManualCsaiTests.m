#import <XCTest/XCTest.h>

#import "ManualAdBreak.h"
#import "ManualVastPayload.h"

// `{"user_id":"u1","vast_config_url":"get.truex.com/abc/vast/config"}`, wrapped like the ad server does.
static NSString *const kCompanionDataUrl =
    @"data:application/json;base64,eyJ1c2VyX2lkIjoidTEiLCJ2YXN0X2NvbmZpZ191cmwiOiJnZXQudHJ1ZXguY29tL2Fi\n"
    @"        Yy92YXN0L2NvbmZpZyJ9";

static NSData *CompanionVast(NSString *apiFramework, NSString *resource, NSString *_Nullable adParameters) {
    NSString *linear =
        adParameters ? [NSString stringWithFormat:@"<AdParameters><![CDATA[%@]]></AdParameters>", adParameters] : @"";
    NSString *vast = [NSString
        stringWithFormat:@"<VAST version=\"4.0\"><Ad id=\"super_tag\"><InLine><AdSystem>trueX</AdSystem><Creatives>"
                         @"<Creative id=\"super_tag\"><CompanionAds required=\"all\">"
                         @"<Companion id=\"super_tag\" width=\"960\" height=\"540\" apiFramework=\"%@\">"
                         @"<StaticResource creativeType=\"application/json\"><![CDATA[ %@ ]]></StaticResource>"
                         @"</Companion></CompanionAds></Creative>"
                         @"<Creative id=\"placeholder_video\"><Linear><Duration>00:00:30</Duration>%@</Linear>"
                         @"</Creative></Creatives></InLine></Ad></VAST>",
                         apiFramework, resource, linear];
    return [vast dataUsingEncoding:NSUTF8StringEncoding];
}

@interface ManualCsaiTests : XCTestCase
@end

@implementation ManualCsaiTests

- (void)testClassifiesAdSystemCaseInsensitively {
    XCTAssertEqual(ClassifyManualAd(@"trueX"), ManualAdTypeTruex);
    XCTAssertEqual(ClassifyManualAd(@"TRUEX"), ManualAdTypeTruex);
    XCTAssertEqual(ClassifyManualAd(@"IDVx"), ManualAdTypeIdvx);
    XCTAssertEqual(ClassifyManualAd(@"idvx"), ManualAdTypeIdvx);
    XCTAssertEqual(ClassifyManualAd(@"GDFP"), ManualAdTypeLinear);
    XCTAssertEqual(ClassifyManualAd(nil), ManualAdTypeLinear);
}

- (void)testTruexIsInteractiveOnlyAsFirstAdInPod {
    XCTAssertTrue(CanPlayInteractive(ManualAdTypeTruex, 1));
    XCTAssertFalse(CanPlayInteractive(ManualAdTypeTruex, 2));
    XCTAssertTrue(CanPlayInteractive(ManualAdTypeIdvx, 1));
    XCTAssertTrue(CanPlayInteractive(ManualAdTypeIdvx, 3));
    XCTAssertFalse(CanPlayInteractive(ManualAdTypeLinear, 1));
}

- (void)testOnlyTruexCreditSkipsRemainingPod {
    XCTAssertTrue(ShouldSkipRemainingPod(ManualAdTypeTruex, YES));
    XCTAssertFalse(ShouldSkipRemainingPod(ManualAdTypeTruex, NO));
    XCTAssertFalse(ShouldSkipRemainingPod(ManualAdTypeIdvx, YES));
    XCTAssertFalse(ShouldSkipRemainingPod(ManualAdTypeLinear, YES));
}

- (void)testBundledAdBreakDecodes {
    ManualAdBreak *adBreak = [ManualAdBreak loadFromBundleWithError:nil];
    XCTAssertNotNil(adBreak);
    XCTAssertEqual(adBreak.ads.count, 4u);
    XCTAssertEqual(adBreak.ads[0].type, ManualAdTypeTruex);
    XCTAssertEqual(adBreak.ads[1].type, ManualAdTypeIdvx);
    XCTAssertEqual(adBreak.ads[2].type, ManualAdTypeLinear);
    XCTAssertEqual(adBreak.ads[3].type, ManualAdTypeLinear);
    XCTAssertEqual(adBreak.timeOffsetSeconds, 10);
}

- (void)testUserIdMacroIsReplaced {
    ManualAd *ad = [ManualAdBreak loadFromBundleWithError:nil].ads[0];
    NSString *url = [ad resolvedVastUrlWithUserId:@"ref-app-test"].absoluteString;
    XCTAssertTrue([url containsString:@"network_user_id=ref-app-test"]);
    XCTAssertFalse([url containsString:@"${user-id}"]);
}

- (void)testParsesAdParametersFromLinear {
    NSString *vast =
        @"<VAST version=\"4.0\"><Ad id=\"super_tag\"><InLine><AdSystem>trueX</AdSystem><Creatives><Creative>"
        @"<Linear><Duration>00:00:30</Duration>"
        @"<AdParameters><![CDATA[{\"user_id\":\"u1\",\"vast_config_url\":\"get.truex.com/abc/vast/config\"}]]>"
        @"</AdParameters></Linear></Creative></Creatives></InLine></Ad></VAST>";
    NSDictionary *adParameters = [ManualVastPayload parseVast:[vast dataUsingEncoding:NSUTF8StringEncoding]];
    XCTAssertEqualObjects(adParameters[@"user_id"], @"u1");
    XCTAssertEqualObjects(adParameters[@"vast_config_url"], @"get.truex.com/abc/vast/config");
}

- (void)testEmptyVastHasNoAdParameters {
    NSString *vast = @"<?xml version=\"1.0\"?><VAST version=\"2.0\"/>";
    XCTAssertNil([ManualVastPayload parseVast:[vast dataUsingEncoding:NSUTF8StringEncoding]]);
}

- (void)testInvalidAdParametersJsonIsRejected {
    NSString *vast = @"<VAST><Ad><InLine><Creatives><Creative><Linear><AdParameters>not json</AdParameters></Linear>"
                     @"</Creative></Creatives></InLine></Ad></VAST>";
    XCTAssertNil([ManualVastPayload parseVast:[vast dataUsingEncoding:NSUTF8StringEncoding]]);
}

- (void)testParsesAdParametersFromTruexCompanion {
    NSDictionary *adParameters = [ManualVastPayload parseVast:CompanionVast(@"truex", kCompanionDataUrl, nil)];
    XCTAssertEqualObjects(adParameters[@"user_id"], @"u1");
    XCTAssertEqualObjects(adParameters[@"vast_config_url"], @"get.truex.com/abc/vast/config");
}

- (void)testCompanionWinsOverAdParameters {
    NSData *vast = CompanionVast(@"truex", kCompanionDataUrl, @"{\"user_id\":\"linear\"}");
    XCTAssertEqualObjects([ManualVastPayload parseVast:vast][@"user_id"], @"u1");
}

- (void)testFallsBackToAdParametersWhenCompanionIsInvalid {
    NSData *vast = CompanionVast(@"truex", @"data:application/json;base64,!!!", @"{\"user_id\":\"linear\"}");
    XCTAssertEqualObjects([ManualVastPayload parseVast:vast][@"user_id"], @"linear");
}

- (void)testIgnoresNonTruexCompanion {
    XCTAssertNil([ManualVastPayload parseVast:CompanionVast(@"VPAID", kCompanionDataUrl, nil)]);
}

- (void)testKeepsPlainJsonCompanionResourceUnchanged {
    NSDictionary *adParameters =
        [ManualVastPayload companionAdParameters:@"  {\"user_id\":\"plain\",\"user_name\":\"first last\"}  "];
    XCTAssertEqualObjects(adParameters[@"user_id"], @"plain");
    XCTAssertEqualObjects(adParameters[@"user_name"], @"first last");
}

- (void)testReadsPlainJsonCompanionResource {
    XCTAssertEqualObjects([ManualVastPayload companionAdParameters:@"{\"user_id\":\"plain\"}"][@"user_id"], @"plain");
}

@end
