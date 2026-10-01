#import "TruexRendererFactory.h"

@implementation TruexRendererFactory

+ (TruexAdRenderer *)rendererWithAdParameters:(NSDictionary *)adParameters
                                     delegate:(id<TruexAdRendererDelegate>)delegate {
    TruexAdOptions options = DefaultOptions();
    options.supportsUserCancelStream = YES;
#if DEBUG
    options.enableWebViewDebugging = YES;
#endif
    return [[TruexAdRenderer alloc] initWithAdParameters:adParameters
                                                 options:options
                                                delegate:delegate];
}

@end
