#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Fetches an Infillion VAST tag and returns its `adParameters` JSON.
///
/// Infillion tags deliver `adParameters` in one of two formats:
/// - Companion tag (`/vast/companion`, `/vast/idvx/companion`): a base64 JSON `data:` URL in
///   `<Companion apiFramework="truex"><StaticResource creativeType="application/json">`.
/// - Generic tag (`/vast/generic`, `/vast/idvx/generic`): the JSON in `<Linear><AdParameters>`.
///
/// The companion is checked first, then `<AdParameters>`.
@interface ManualVastPayload : NSObject

/// Calls `completion` on the main queue. Cancel the returned task when the result is no longer needed.
+ (NSURLSessionDataTask *)loadFromURL:(NSURL *)url
                           completion:
                               (void (^)(NSDictionary *_Nullable adParameters, NSError *_Nullable error))completion;

/// Returns nil when the VAST has no ad or neither format holds a JSON object.
+ (nullable NSDictionary *)parseVast:(NSData *)vast;

/// Decodes a `data:application/json;base64,...` URL. Any other resource is read as plain JSON.
+ (nullable NSDictionary *)companionAdParameters:(NSString *)resource;

@end

NS_ASSUME_NONNULL_END
