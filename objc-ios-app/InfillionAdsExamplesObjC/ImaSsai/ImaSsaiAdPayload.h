#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ImaSsaiAdType) {
    ImaSsaiAdTypeTruex,
    ImaSsaiAdTypeIdvx,
    ImaSsaiAdTypeLinear,
};

/// Infillion ads are detected by the IMA ad's `adSystem`, compared case-insensitively.
FOUNDATION_EXTERN ImaSsaiAdType ClassifyImaSsaiAd(NSString *_Nullable adSystem);

/// TrueX is interactive only as the first ad in a pod; elsewhere it plays as a normal linear ad.
/// IDVx is interactive in any position.
FOUNDATION_EXTERN BOOL CanPlayImaSsaiInteractive(ImaSsaiAdType type, NSInteger adPosition);

/// Only a TrueX ad that earned credit (`onAdFreePod`) skips the rest of the ad break.
FOUNDATION_EXTERN BOOL ShouldSkipImaSsaiAdBreak(ImaSsaiAdType type, BOOL earnedCredit);

/// IMA exposes the VAST `<AdParameters>` JSON as `traffickingParameters`.
/// Returns nil when it is missing or not a JSON object.
FOUNDATION_EXTERN NSDictionary *_Nullable ImaSsaiAdParameters(NSString *_Nullable traffickingParameters);

/// Stream time just before the placeholder ad ends, so the stitched stream moves on to the next ad.
FOUNDATION_EXTERN double ImaSsaiPlaceholderEndTime(double adStartStreamTime, double adDuration);

/// Stream time just past the current ad break, so the rest of the break is skipped.
FOUNDATION_EXTERN double ImaSsaiAdBreakSkipTime(double adBreakEndStreamTime);

NS_ASSUME_NONNULL_END
