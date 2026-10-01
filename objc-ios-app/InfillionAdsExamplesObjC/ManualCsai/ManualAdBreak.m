#import "ManualAdBreak.h"

ManualAdType ClassifyManualAd(NSString *adSystem) {
    NSString *system = adSystem.lowercaseString;
    if ([system isEqualToString:@"truex"]) {
        return ManualAdTypeTruex;
    }
    if ([system isEqualToString:@"idvx"]) {
        return ManualAdTypeIdvx;
    }
    return ManualAdTypeLinear;
}

BOOL CanPlayInteractive(ManualAdType type, NSInteger adPosition) {
    switch (type) {
        case ManualAdTypeTruex:
            return adPosition == 1;
        case ManualAdTypeIdvx:
            return YES;
        case ManualAdTypeLinear:
            return NO;
    }
}

BOOL ShouldSkipRemainingPod(ManualAdType type, BOOL earnedCredit) {
    return type == ManualAdTypeTruex && earnedCredit;
}

@implementation ManualAd

- (nullable instancetype)initWithJson:(NSDictionary *)json {
    self = [super init];
    if (self) {
        _adId = [json[@"id"] copy];
        _adSystem = [json[@"adSystem"] copy];
        _mediaUrl = [NSURL URLWithString:json[@"mediaUrl"] ?: @""];
        _vastUrl = [json[@"vastUrl"] copy];
        _durationSeconds = [json[@"durationSeconds"] doubleValue];
        if (!_adId || !_adSystem || !_mediaUrl) {
            return nil;
        }
    }
    return self;
}

- (ManualAdType)type {
    return ClassifyManualAd(self.adSystem);
}

- (NSURL *)resolvedVastUrlWithUserId:(NSString *)userId {
    if (!self.vastUrl) {
        return nil;
    }
    return [NSURL URLWithString:[self.vastUrl stringByReplacingOccurrencesOfString:@"${user-id}" withString:userId]];
}

@end

@implementation ManualAdBreak

+ (instancetype)loadFromBundleWithError:(NSError **)error {
    NSURL *url = [NSBundle.mainBundle URLForResource:@"manual_ad_break" withExtension:@"json"];
    NSData *data = url ? [NSData dataWithContentsOfURL:url options:0 error:error] : nil;
    if (!data) {
        if (error && !*error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil];
        }
        return nil;
    }
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    if (![json isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    ManualAdBreak *adBreak = [[ManualAdBreak alloc] init];
    adBreak->_breakId = [json[@"breakId"] copy];
    adBreak->_timeOffsetSeconds = [json[@"timeOffsetSeconds"] doubleValue];
    NSMutableArray<ManualAd *> *ads = [NSMutableArray array];
    for (NSDictionary *adJson in json[@"ads"]) {
        ManualAd *ad = [[ManualAd alloc] initWithJson:adJson];
        if (ad) {
            [ads addObject:ad];
        }
    }
    adBreak->_ads = ads;
    return adBreak;
}

@end
