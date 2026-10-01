#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ManualAdType) {
    ManualAdTypeTruex,
    ManualAdTypeIdvx,
    ManualAdTypeLinear,
};

/// Infillion ads are detected by their VAST `<AdSystem>`, compared case-insensitively.
FOUNDATION_EXTERN ManualAdType ClassifyManualAd(NSString *_Nullable adSystem);

/// TrueX is interactive only as the first ad in a pod; elsewhere it plays as a normal linear ad.
/// IDVx is interactive in any position.
FOUNDATION_EXTERN BOOL CanPlayInteractive(ManualAdType type, NSInteger adPosition);

/// Only a TrueX ad that earned credit (`onAdFreePod`) skips the rest of the pod.
FOUNDATION_EXTERN BOOL ShouldSkipRemainingPod(ManualAdType type, BOOL earnedCredit);

@interface ManualAd : NSObject

@property(nonatomic, copy, readonly) NSString *adId;
@property(nonatomic, copy, readonly) NSString *adSystem;
@property(nonatomic, copy, readonly) NSURL *mediaUrl;
@property(nonatomic, copy, readonly, nullable) NSString *vastUrl;
@property(nonatomic, readonly) double durationSeconds;
@property(nonatomic, readonly) ManualAdType type;

/// The sample tags carry a `${user-id}` macro that a real ad server would fill in.
- (nullable NSURL *)resolvedVastUrlWithUserId:(NSString *)userId;

@end

@interface ManualAdBreak : NSObject

@property(nonatomic, copy, readonly) NSString *breakId;
@property(nonatomic, readonly) double timeOffsetSeconds;
@property(nonatomic, copy, readonly) NSArray<ManualAd *> *ads;

+ (nullable instancetype)loadFromBundleWithError:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
