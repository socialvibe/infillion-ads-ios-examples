#import "ImaSsaiAdPayload.h"

ImaSsaiAdType ClassifyImaSsaiAd(NSString *adSystem) {
    NSString *system = adSystem.lowercaseString;
    if ([system isEqualToString:@"truex"]) {
        return ImaSsaiAdTypeTruex;
    }
    if ([system isEqualToString:@"idvx"]) {
        return ImaSsaiAdTypeIdvx;
    }
    return ImaSsaiAdTypeLinear;
}

BOOL CanPlayImaSsaiInteractive(ImaSsaiAdType type, NSInteger adPosition) {
    switch (type) {
        case ImaSsaiAdTypeTruex:
            return adPosition == 1;
        case ImaSsaiAdTypeIdvx:
            return YES;
        case ImaSsaiAdTypeLinear:
            return NO;
    }
}

BOOL ShouldSkipImaSsaiAdBreak(ImaSsaiAdType type, BOOL earnedCredit) {
    return type == ImaSsaiAdTypeTruex && earnedCredit;
}

NSDictionary *ImaSsaiAdParameters(NSString *traffickingParameters) {
    NSData *json =
        [[traffickingParameters stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
            dataUsingEncoding:NSUTF8StringEncoding];
    if (json.length == 0) {
        return nil;
    }
    id object = [NSJSONSerialization JSONObjectWithData:json options:0 error:nil];
    return [object isKindOfClass:[NSDictionary class]] ? object : nil;
}

double ImaSsaiPlaceholderEndTime(double adStartStreamTime, double adDuration) {
    return MAX(0, adStartStreamTime + adDuration - 0.1);
}

double ImaSsaiAdBreakSkipTime(double adBreakEndStreamTime) {
    return adBreakEndStreamTime + 0.1;
}
