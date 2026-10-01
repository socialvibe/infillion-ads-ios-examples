#import <Foundation/Foundation.h>

#import "ImaSsaiAdPayload.h"

NS_ASSUME_NONNULL_BEGIN

// For demo purposes only. Do not use in production: read `adParameters` from the ad
// (`traffickingParameters`, see `ImaSsaiAdParameters`).
//
// This sample takes the Infillion ads' `adParameters` from the iOS sample tags instead of from the DAI stream.
@interface ImaSsaiDemoAdParameters : NSObject

/// Fetched for every ad, so each ad gets a fresh ad session. Calls `completion` on the main queue.
+ (nullable NSURLSessionDataTask *)loadForType:(ImaSsaiAdType)type
                                    completion:(void (^)(NSDictionary *_Nullable adParameters))completion;

@end

NS_ASSUME_NONNULL_END
