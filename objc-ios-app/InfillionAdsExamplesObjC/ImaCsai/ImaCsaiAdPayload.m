#import "ImaCsaiAdPayload.h"

#import <GoogleInteractiveMediaAds/GoogleInteractiveMediaAds.h>

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

static NSDictionary *ImaCsaiJsonObject(NSString *text) {
    NSData *json = [[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
        dataUsingEncoding:NSUTF8StringEncoding];
    if (json.length == 0) {
        return nil;
    }
    id object = [NSJSONSerialization JSONObjectWithData:json options:0 error:nil];
    return [object isKindOfClass:[NSDictionary class]] ? object : nil;
}

NSDictionary *ImaCsaiAdParameters(NSArray<IMACompanionAd *> *companionAds, NSString *traffickingParameters) {
    for (IMACompanionAd *companion in companionAds) {
        if (![companion.APIFramework.lowercaseString isEqualToString:@"truex"] || !companion.resourceValue) {
            continue;
        }
        NSDictionary *adParameters = ImaCsaiCompanionAdParameters(companion.resourceValue);
        if (adParameters) {
            return adParameters;
        }
    }
    return ImaCsaiJsonObject(traffickingParameters);
}

NSDictionary *ImaCsaiCompanionAdParameters(NSString *resource) {
    NSString *trimmed = [resource stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (![trimmed.lowercaseString hasPrefix:@"data:"]) {
        return ImaCsaiJsonObject(trimmed);
    }
    // The ad server wraps the base64 payload across lines, so whitespace is removed before decoding.
    NSString *compact = [[trimmed componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
        componentsJoinedByString:@""];
    NSRange comma = [compact rangeOfString:@","];
    if (comma.location == NSNotFound) {
        return nil;
    }
    NSData *decoded = [[NSData alloc] initWithBase64EncodedString:[compact substringFromIndex:NSMaxRange(comma)]
                                                          options:0];
    if (!decoded) {
        return nil;
    }
    id object = [NSJSONSerialization JSONObjectWithData:decoded options:0 error:nil];
    return [object isKindOfClass:[NSDictionary class]] ? object : nil;
}
