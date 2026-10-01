#import <UIKit/UIKit.h>

/// Plain / Manual CSAI: the app owns the ad break.
///
/// At the break offset the app pauses content, fetches the Infillion VAST tags, and plays the pod ad by ad.
/// TrueX and IDVx ads run in `TruexAdRenderer`; other ads play as linear video. TrueX credit skips the rest of the pod.
@interface ManualCsaiViewController : UIViewController
@end
