#import "ImaSsaiDemoAdParameters.h"

static NSString *const kTruexTag =
    @"https://get.truex.com/22c36d3926383ba62994809a60b4649e3ced1070/vast/generic?ip=158.106.195.210";
static NSString *const kIdvxTag =
    @"https://get.truex.com/132f66121635ac312e42f1eb018081d50d10fe2a/vast/idvx/generic?ip=158.106.195.210";

@interface DemoAdParametersParser : NSObject <NSXMLParserDelegate>

@property(nonatomic, copy, nullable) NSString *adParameters;

@end

@implementation DemoAdParametersParser {
    NSMutableString *_buffer;
}

- (void)parser:(NSXMLParser *)parser
    didStartElement:(NSString *)elementName
       namespaceURI:(NSString *)namespaceURI
      qualifiedName:(NSString *)qualifiedName
         attributes:(NSDictionary<NSString *, NSString *> *)attributes {
    if ([elementName isEqualToString:@"AdParameters"] && !self.adParameters) {
        _buffer = [NSMutableString string];
    }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    [_buffer appendString:string];
}

- (void)parser:(NSXMLParser *)parser foundCDATA:(NSData *)cdataBlock {
    [_buffer appendString:[[NSString alloc] initWithData:cdataBlock encoding:NSUTF8StringEncoding] ?: @""];
}

- (void)parser:(NSXMLParser *)parser
    didEndElement:(NSString *)elementName
     namespaceURI:(NSString *)namespaceURI
    qualifiedName:(NSString *)qualifiedName {
    if ([elementName isEqualToString:@"AdParameters"] && _buffer) {
        self.adParameters = _buffer;
        _buffer = nil;
    }
}

@end

@implementation ImaSsaiDemoAdParameters

+ (NSURLSessionDataTask *)loadForType:(ImaSsaiAdType)type completion:(void (^)(NSDictionary *adParameters))completion {
    NSString *tag = nil;
    if (type == ImaSsaiAdTypeTruex) {
        tag = kTruexTag;
    } else if (type == ImaSsaiAdTypeIdvx) {
        tag = kIdvxTag;
    }
    if (!tag) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(nil);
        });
        return nil;
    }
    NSURLSessionDataTask *task =
        [NSURLSession.sharedSession dataTaskWithURL:[NSURL URLWithString:tag]
                                  completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                      NSDictionary *adParameters = nil;
                                      if (data) {
                                          DemoAdParametersParser *delegate = [[DemoAdParametersParser alloc] init];
                                          NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
                                          parser.delegate = delegate;
                                          [parser parse];
                                          adParameters = ImaSsaiAdParameters(delegate.adParameters);
                                      }
                                      dispatch_async(dispatch_get_main_queue(), ^{
                                          completion(adParameters);
                                      });
                                  }];
    [task resume];
    return task;
}

@end
