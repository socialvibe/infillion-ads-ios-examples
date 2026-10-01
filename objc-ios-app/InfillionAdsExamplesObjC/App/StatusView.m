#import "StatusView.h"

#import "Theme.h"

void ExampleLog(NSString *format, ...) {
    va_list arguments;
    va_start(arguments, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    NSLog(@"[InfillionAdsExamples] %@", message);
}

@implementation StatusView {
    UILabel *_label;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [Theme.deepCharcoal colorWithAlphaComponent:0.85];
        self.layer.cornerRadius = 12;
        self.layer.cornerCurve = kCACornerCurveContinuous;
        self.userInteractionEnabled = NO;

        _label = [[UILabel alloc] init];
        _label.font = [Theme fontWithWeight:UIFontWeightMedium size:13 textStyle:UIFontTextStyleFootnote];
        _label.adjustsFontForContentSizeCategory = YES;
        _label.textColor = Theme.fogGray;
        _label.numberOfLines = 0;
        _label.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_label];
        [NSLayoutConstraint activateConstraints:@[
            [_label.topAnchor constraintEqualToAnchor:self.topAnchor constant:8],
            [_label.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-8],
            [_label.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
            [_label.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12],
        ]];
    }
    return self;
}

- (NSString *)text {
    return _label.text;
}

- (void)setText:(NSString *)text {
    _label.text = text;
    if (text) {
        ExampleLog(@"%@", text);
    }
}

- (void)installInViewController:(UIViewController *)viewController {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    [viewController.view addSubview:self];
    UILayoutGuide *guide = viewController.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.topAnchor constraintEqualToAnchor:guide.topAnchor constant:12],
        [self.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor constant:16],
        [self.trailingAnchor constraintLessThanOrEqualToAnchor:guide.trailingAnchor constant:-16],
    ]];
}

@end
