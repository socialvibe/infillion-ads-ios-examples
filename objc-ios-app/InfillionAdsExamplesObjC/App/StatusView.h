#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Logs to the unified log, so messages show up in Console and `log stream` as well as in Xcode.
void ExampleLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);

/// Compact status surface for player screens: content, ad request, linear ad, interactive ad, recovery, or error.
@interface StatusView : UIView

@property(nonatomic, copy, nullable) NSString *text;

/// Pins the status surface to the upper-left safe area of `viewController`.
- (void)installInViewController:(UIViewController *)viewController;

@end

NS_ASSUME_NONNULL_END
