#import "Theme.h"

static UIColor *ColorFromRGB(uint32_t rgb) {
    return [UIColor colorWithRed:((rgb >> 16) & 0xFF) / 255.0
                           green:((rgb >> 8) & 0xFF) / 255.0
                            blue:(rgb & 0xFF) / 255.0
                           alpha:1];
}

@implementation Theme

+ (UIColor *)charcoal {
    return ColorFromRGB(0x2D2D2D);
}

+ (UIColor *)deepCharcoal {
    return ColorFromRGB(0x242222);
}

+ (UIColor *)fogGray {
    return ColorFromRGB(0xF6F6F6);
}

+ (UIColor *)mutedFog {
    return ColorFromRGB(0xE4E4E4);
}

+ (UIColor *)bloomPink {
    return ColorFromRGB(0xF948A1);
}

+ (NSArray<UIColor *> *)bloomColors {
    return @[ ColorFromRGB(0xBB6AEF), ColorFromRGB(0xF948A1), ColorFromRGB(0xFC5D3D) ];
}

+ (UIFont *)fontWithWeight:(UIFontWeight)weight size:(CGFloat)size textStyle:(UIFontTextStyle)textStyle {
    NSString *name = @"BeVietnamPro-Regular";
    if (weight == UIFontWeightBold) {
        name = @"BeVietnamPro-Bold";
    } else if (weight == UIFontWeightMedium) {
        name = @"BeVietnamPro-Medium";
    }
    UIFont *font = [UIFont fontWithName:name size:size] ?: [UIFont systemFontOfSize:size weight:weight];
    return [[UIFontMetrics metricsForTextStyle:textStyle] scaledFontForFont:font];
}

+ (void)styleNavigationBar:(UINavigationBar *)navigationBar {
    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithOpaqueBackground];
    appearance.backgroundColor = self.charcoal;
    appearance.shadowColor = UIColor.clearColor;
    appearance.titleTextAttributes = @{
        NSForegroundColorAttributeName : self.fogGray,
        NSFontAttributeName : [self fontWithWeight:UIFontWeightMedium size:17 textStyle:UIFontTextStyleHeadline],
    };
    navigationBar.standardAppearance = appearance;
    navigationBar.scrollEdgeAppearance = appearance;
    navigationBar.compactAppearance = appearance;
    navigationBar.tintColor = self.fogGray;
}

@end
