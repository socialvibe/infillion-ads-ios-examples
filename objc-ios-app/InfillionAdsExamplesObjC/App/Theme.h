#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Launcher styling from DESIGN.md. Player screens keep color restrained so the ad stays primary.
@interface Theme : NSObject

@property(class, nonatomic, readonly) UIColor *charcoal;
@property(class, nonatomic, readonly) UIColor *deepCharcoal;
@property(class, nonatomic, readonly) UIColor *fogGray;
@property(class, nonatomic, readonly) UIColor *mutedFog;
@property(class, nonatomic, readonly) UIColor *bloomPink;
@property(class, nonatomic, readonly) NSArray<UIColor *> *bloomColors;

+ (UIFont *)fontWithWeight:(UIFontWeight)weight size:(CGFloat)size textStyle:(UIFontTextStyle)textStyle;
+ (void)styleNavigationBar:(UINavigationBar *)navigationBar;

@end

NS_ASSUME_NONNULL_END
