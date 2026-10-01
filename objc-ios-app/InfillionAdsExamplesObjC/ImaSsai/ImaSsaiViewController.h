#import <UIKit/UIKit.h>

/// Google IMA SSAI: a Google DAI VOD stream with stitched ad breaks.
///
/// When IMA starts a TrueX or IDVx placeholder ad, the app pauses the stream and runs `TruexAdRenderer`.
/// Afterwards it seeks past the whole ad break (TrueX credit) or to the end of the placeholder (no credit).
/// DAI has no `discardAdBreak`, so every skip is a stream seek.
@interface ImaSsaiViewController : UIViewController
@end
