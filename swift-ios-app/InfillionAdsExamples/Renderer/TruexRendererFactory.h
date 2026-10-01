#import <TruexAdRenderer/TruexAdRenderer.h>

NS_ASSUME_NONNULL_BEGIN

/// Swift can't import the `TruexAdOptions` C struct, so the renderer is created here.
@interface TruexRendererFactory : NSObject

+ (nullable TruexAdRenderer *)rendererWithAdParameters:(NSDictionary *)adParameters
                                              delegate:(id<TruexAdRendererDelegate>)delegate;

@end

NS_ASSUME_NONNULL_END
