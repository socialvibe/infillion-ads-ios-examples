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

@class IMACompanionAd;

/// Infillion tags deliver `adParameters` as a `truex` companion (companion tag) or as `<AdParameters>` (generic tag).
/// IMA exposes them as `ad.companionAds` and `ad.traffickingParameters`; the companion is checked first.
/// Returns nil when neither holds a JSON object.
FOUNDATION_EXTERN NSDictionary *_Nullable ImaCsaiAdParameters(NSArray<IMACompanionAd *> *_Nullable companionAds,
                                                              NSString *_Nullable traffickingParameters);

/// Decodes a `data:application/json;base64,...` URL. Any other resource is read as plain JSON.
FOUNDATION_EXTERN NSDictionary *_Nullable ImaCsaiCompanionAdParameters(NSString *resource);

NS_ASSUME_NONNULL_END
