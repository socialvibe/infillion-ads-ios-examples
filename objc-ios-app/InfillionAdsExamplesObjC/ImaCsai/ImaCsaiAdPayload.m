#import "ImaCsaiAdPayload.h"

ImaCsaiAdType ClassifyImaCsaiAd(NSString *adSystem) {
    NSString *system = adSystem.lowercaseString;
    if ([system isEqualToString:@"truex"]) {
        return ImaCsaiAdTypeTruex;
    }
    if ([system isEqualToString:@"idvx"]) {
        return ImaCsaiAdTypeIdvx;
    }
    return ImaCsaiAdTypeLinear;
}

BOOL CanPlayImaCsaiInteractive(ImaCsaiAdType type, NSInteger adPosition) {
    switch (type) {
        case ImaCsaiAdTypeTruex:
            return adPosition == 1;
        case ImaCsaiAdTypeIdvx:
            return YES;
        case ImaCsaiAdTypeLinear:
            return NO;
    }
}

BOOL ShouldDiscardImaCsaiAdBreak(ImaCsaiAdType type, BOOL earnedCredit) {
    return type == ImaCsaiAdTypeTruex && earnedCredit;
}

NSDictionary *ImaCsaiAdParameters(NSString *traffickingParameters) {
    NSData *json =
        [[traffickingParameters stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
            dataUsingEncoding:NSUTF8StringEncoding];
    if (json.length == 0) {
        return nil;
    }
    id object = [NSJSONSerialization JSONObjectWithData:json options:0 error:nil];
    return [object isKindOfClass:[NSDictionary class]] ? object : nil;
}
