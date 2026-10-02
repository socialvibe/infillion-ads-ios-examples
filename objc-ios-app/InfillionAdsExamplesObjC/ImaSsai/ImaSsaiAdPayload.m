#import "ImaSsaiAdPayload.h"

#import <GoogleInteractiveMediaAds/GoogleInteractiveMediaAds.h>

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

static NSDictionary *ImaSsaiJsonObject(NSString *text) {
    NSData *json = [[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
        dataUsingEncoding:NSUTF8StringEncoding];
    if (json.length == 0) {
        return nil;
    }
    id object = [NSJSONSerialization JSONObjectWithData:json options:0 error:nil];
    return [object isKindOfClass:[NSDictionary class]] ? object : nil;
}

NSDictionary *ImaSsaiAdParameters(NSArray<IMACompanionAd *> *companionAds, NSString *traffickingParameters) {
    for (IMACompanionAd *companion in companionAds) {
        if (![companion.APIFramework.lowercaseString isEqualToString:@"truex"] || !companion.resourceValue) {
            continue;
        }
        NSDictionary *adParameters = ImaSsaiCompanionAdParameters(companion.resourceValue);
        if (adParameters) {
            return adParameters;
        }
    }
    return ImaSsaiJsonObject(traffickingParameters);
}

NSDictionary *ImaSsaiCompanionAdParameters(NSString *resource) {
    NSString *trimmed = [resource stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (![trimmed.lowercaseString hasPrefix:@"data:"]) {
        return ImaSsaiJsonObject(trimmed);
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

double ImaSsaiPlaceholderEndTime(double adStartStreamTime, double adDuration) {
    return MAX(0, adStartStreamTime + adDuration - 0.1);
}

double ImaSsaiAdBreakSkipTime(double adBreakEndStreamTime) {
    return adBreakEndStreamTime + 0.1;
}
