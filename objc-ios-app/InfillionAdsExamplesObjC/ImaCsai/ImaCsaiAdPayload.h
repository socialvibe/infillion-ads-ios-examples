#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ImaCsaiAdType) {
    ImaCsaiAdTypeTruex,
    ImaCsaiAdTypeIdvx,
    ImaCsaiAdTypeLinear,
};

/// Infillion ads are detected by the IMA ad's `adSystem`, compared case-insensitively.
FOUNDATION_EXTERN ImaCsaiAdType ClassifyImaCsaiAd(NSString *_Nullable adSystem);

/// TrueX is interactive only as the first ad in a pod; elsewhere it plays as a normal linear ad.
/// IDVx is interactive in any position.
FOUNDATION_EXTERN BOOL CanPlayImaCsaiInteractive(ImaCsaiAdType type, NSInteger adPosition);

/// Only a TrueX ad that earned credit (`onAdFreePod`) skips the rest of the pod.
FOUNDATION_EXTERN BOOL ShouldDiscardImaCsaiAdBreak(ImaCsaiAdType type, BOOL earnedCredit);

/// IMA exposes the VAST `<AdParameters>` JSON as `traffickingParameters`.
/// Returns nil when it is missing or not a JSON object.
FOUNDATION_EXTERN NSDictionary *_Nullable ImaCsaiAdParameters(NSString *_Nullable traffickingParameters);

NS_ASSUME_NONNULL_END
