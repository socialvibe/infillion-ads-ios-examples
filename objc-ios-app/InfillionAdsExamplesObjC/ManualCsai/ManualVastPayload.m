#import "ManualVastPayload.h"

static NSDictionary *JsonObject(NSString *text) {
    NSData *json = [[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
        dataUsingEncoding:NSUTF8StringEncoding];
    if (json.length == 0) {
        return nil;
    }
    id object = [NSJSONSerialization JSONObjectWithData:json options:0 error:nil];
    return [object isKindOfClass:[NSDictionary class]] ? object : nil;
}

@interface AdParametersParser : NSObject <NSXMLParserDelegate>

@property(nonatomic, copy, nullable) NSString *adParameters;
@property(nonatomic, copy, nullable) NSString *companionResource;

@end

@implementation AdParametersParser {
    BOOL _inLinear;
    BOOL _inTruexCompanion;
    NSMutableString *_adParametersBuffer;
    NSMutableString *_companionBuffer;
}

- (void)parser:(NSXMLParser *)parser
    didStartElement:(NSString *)elementName
       namespaceURI:(NSString *)namespaceURI
      qualifiedName:(NSString *)qualifiedName
         attributes:(NSDictionary<NSString *, NSString *> *)attributes {
    if ([elementName isEqualToString:@"Linear"]) {
        _inLinear = YES;
    } else if ([elementName isEqualToString:@"AdParameters"] && _inLinear && !self.adParameters) {
        _adParametersBuffer = [NSMutableString string];
    } else if ([elementName isEqualToString:@"Companion"]) {
        _inTruexCompanion = [attributes[@"apiFramework"].lowercaseString isEqualToString:@"truex"];
    } else if ([elementName isEqualToString:@"StaticResource"] && _inTruexCompanion && !self.companionResource) {
        if ([attributes[@"creativeType"].lowercaseString isEqualToString:@"application/json"]) {
            _companionBuffer = [NSMutableString string];
        }
    }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    [_adParametersBuffer appendString:string];
    [_companionBuffer appendString:string];
}

- (void)parser:(NSXMLParser *)parser foundCDATA:(NSData *)cdataBlock {
    NSString *text = [[NSString alloc] initWithData:cdataBlock encoding:NSUTF8StringEncoding] ?: @"";
    [_adParametersBuffer appendString:text];
    [_companionBuffer appendString:text];
}

- (void)parser:(NSXMLParser *)parser
    didEndElement:(NSString *)elementName
     namespaceURI:(NSString *)namespaceURI
    qualifiedName:(NSString *)qualifiedName {
    if ([elementName isEqualToString:@"Linear"]) {
        _inLinear = NO;
    } else if ([elementName isEqualToString:@"AdParameters"] && _adParametersBuffer) {
        self.adParameters = _adParametersBuffer;
        _adParametersBuffer = nil;
    } else if ([elementName isEqualToString:@"Companion"]) {
        _inTruexCompanion = NO;
    } else if ([elementName isEqualToString:@"StaticResource"] && _companionBuffer) {
        self.companionResource = _companionBuffer;
        _companionBuffer = nil;
    }
}

@end

@implementation ManualVastPayload

+ (NSURLSessionDataTask *)loadFromURL:(NSURL *)url
                           completion:(void (^)(NSDictionary *adParameters, NSError *error))completion {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = 15;
    NSURLSessionDataTask *task = [NSURLSession.sharedSession
        dataTaskWithRequest:request
          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
              NSDictionary *adParameters = data ? [self parseVast:data] : nil;
              if (!adParameters && !error) {
                  error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotParseResponse userInfo:nil];
              }
              dispatch_async(dispatch_get_main_queue(), ^{
                  completion(adParameters, error);
              });
          }];
    [task resume];
    return task;
}

+ (NSDictionary *)parseVast:(NSData *)vast {
    AdParametersParser *delegate = [[AdParametersParser alloc] init];
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:vast];
    parser.delegate = delegate;
    [parser parse];
    if (delegate.companionResource) {
        NSDictionary *adParameters = [self companionAdParameters:delegate.companionResource];
        if (adParameters) {
            return adParameters;
        }
    }
    if (delegate.adParameters) {
        return JsonObject(delegate.adParameters);
    }
    return nil;
}

+ (NSDictionary *)companionAdParameters:(NSString *)resource {
    NSString *trimmed = [resource stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (![trimmed.lowercaseString hasPrefix:@"data:"]) {
        return JsonObject(trimmed);
    }
    // The ad server wraps the base64 payload across lines, so whitespace is removed before decoding.
    NSString *compact = [[trimmed componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
        componentsJoinedByString:@""];
    NSRange comma = [compact rangeOfString:@","];
    if (comma.location == NSNotFound) {
        return nil;
    }
    NSData *decoded = [[NSData alloc] initWithBase64EncodedString:[compact substringFromIndex:NSMaxRange(comma)]
                                                          options:0];
    if (!decoded) {
        return nil;
    }
    id object = [NSJSONSerialization JSONObjectWithData:decoded options:0 error:nil];
    return [object isKindOfClass:[NSDictionary class]] ? object : nil;
}

@end
