#import <UIKit/UIKit.h>

/// Google IMA CSAI: IMA requests and sequences client-side ads.
///
/// When IMA starts a TrueX or IDVx placeholder ad, the app pauses IMA, moves the placeholder to its end, and runs
/// `TruexAdRenderer` with the ad's `traffickingParameters`. TrueX credit discards the rest of the ad break.
@interface ImaCsaiViewController : UIViewController
@end
