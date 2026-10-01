#import "HomeViewController.h"

#import <TruexAdRenderer/TruexAdRenderer.h>

#import "ImaCsaiViewController.h"
#import "ImaSsaiViewController.h"
#import "ManualCsaiViewController.h"
#import "Theme.h"

/// Deep Charcoal card with a Bloom accent bar; scales down slightly while pressed.
@interface CardButton : UIControl
@end

@implementation CardButton {
    CAGradientLayer *_accent;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = Theme.deepCharcoal;
        self.layer.cornerRadius = 20;
        self.layer.cornerCurve = kCACornerCurveContinuous;
        self.layer.borderWidth = 1;
        self.layer.borderColor = [Theme.fogGray colorWithAlphaComponent:0.08].CGColor;
        self.clipsToBounds = YES;
        _accent = [CAGradientLayer layer];
        NSMutableArray *colors = [NSMutableArray array];
        for (UIColor *color in Theme.bloomColors) {
            [colors addObject:(id)color.CGColor];
        }
        _accent.colors = colors;
        _accent.startPoint = CGPointMake(0, 0.5);
        _accent.endPoint = CGPointMake(1, 0.5);
        [self.layer addSublayer:_accent];
        self.isAccessibilityElement = YES;
        self.accessibilityTraits = UIAccessibilityTraitButton;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _accent.frame = CGRectMake(0, 0, self.bounds.size.width, 4);
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    [UIView animateWithDuration:0.12
                     animations:^{
                         self.transform =
                             highlighted ? CGAffineTransformMakeScale(0.98, 0.98) : CGAffineTransformIdentity;
                     }];
}

@end

@interface HomeExample : NSObject

@property(nonatomic, copy) NSString *title;
@property(nonatomic, copy) NSString *summary;
@property(nonatomic, copy) NSString *delivery;
@property(nonatomic, copy) NSString *insertion;
@property(nonatomic) Class viewControllerClass;

@end

@implementation HomeExample

+ (instancetype)exampleWithTitle:(NSString *)title
                         summary:(NSString *)summary
                        delivery:(NSString *)delivery
                       insertion:(NSString *)insertion
             viewControllerClass:(Class)viewControllerClass {
    HomeExample *example = [[HomeExample alloc] init];
    example.title = title;
    example.summary = summary;
    example.delivery = delivery;
    example.insertion = insertion;
    example.viewControllerClass = viewControllerClass;
    return example;
}

@end

@implementation HomeViewController {
    NSArray<HomeExample *> *_examples;
}

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _examples = @[
            [HomeExample
                   exampleWithTitle:@"Plain / Manual CSAI"
                            summary:@"Own the ad break yourself: pause content, run the interactive renderer, then "
                                    @"skip or continue the pod."
                           delivery:@"Simulated request"
                          insertion:@"Client-side"
                viewControllerClass:[ManualCsaiViewController class]],
            [HomeExample exampleWithTitle:@"Google IMA CSAI"
                                  summary:@"Let Google IMA request and sequence client-side ads while the app handles "
                                          @"TrueX and IDVx placeholders."
                                 delivery:@"Google IMA"
                                insertion:@"Client-side"
                      viewControllerClass:[ImaCsaiViewController class]],
            [HomeExample
                   exampleWithTitle:@"Google IMA SSAI"
                            summary:@"Play a Google DAI stream, coordinate stitched ad timing, and seek the stream "
                                    @"when TrueX credit is earned."
                           delivery:@"Google DAI"
                          insertion:@"Server-side"
                viewControllerClass:[ImaSsaiViewController class]],
        ];
    }
    return self;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = Theme.charcoal;
    self.navigationItem.backButtonDisplayMode = UINavigationItemBackButtonDisplayModeMinimal;

    UIImageView *logo = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"InfillionLogo"]];
    logo.contentMode = UIViewContentModeScaleAspectFit;
    [logo setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [logo.heightAnchor constraintEqualToConstant:36].active = YES;
    self.navigationItem.titleView = logo;

    UILabel *heading = [self labelWithText:@"Interactive ads examples"
                                      font:[Theme fontWithWeight:UIFontWeightBold
                                                            size:28
                                                       textStyle:UIFontTextStyleLargeTitle]
                                     color:Theme.fogGray];
    UILabel *intro = [self labelWithText:@"TrueX and IDVx ads rendered by TruexAdRenderer-iOS. Each example is "
                                         @"self-contained: pick one and read it top to bottom."
                                    font:[Theme fontWithWeight:UIFontWeightRegular
                                                          size:15
                                                     textStyle:UIFontTextStyleBody]
                                   color:Theme.mutedFog];
    NSString *version = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"-";
    UILabel *footer = [self
        labelWithText:[NSString stringWithFormat:@"App %@ · TruexAdRenderer %@", version, TRUEX_AD_RENDERER_VERSION]
                 font:[Theme fontWithWeight:UIFontWeightMedium size:12 textStyle:UIFontTextStyleCaption1]
                color:[Theme.mutedFog colorWithAlphaComponent:0.6]];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[ heading, intro ]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12;
    [stack setCustomSpacing:28 afterView:intro];
    UIView *lastCard = nil;
    for (NSUInteger index = 0; index < _examples.count; index++) {
        lastCard = [self cardForExample:_examples[index] tag:index];
        [stack addArrangedSubview:lastCard];
    }
    [stack addArrangedSubview:footer];
    [stack setCustomSpacing:16 afterView:lastCard];
    stack.translatesAutoresizingMaskIntoConstraints = NO;

    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.alwaysBounceVertical = YES;
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [scrollView addSubview:stack];
    [self.view addSubview:scrollView];

    UILayoutGuide *content = scrollView.contentLayoutGuide;
    UILayoutGuide *frame = scrollView.frameLayoutGuide;
    NSLayoutConstraint *fullWidth = [stack.widthAnchor constraintEqualToAnchor:frame.widthAnchor constant:-40];
    fullWidth.priority = UILayoutPriorityRequired - 1;
    [NSLayoutConstraint activateConstraints:@[
        [scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [content.widthAnchor constraintEqualToAnchor:frame.widthAnchor],
        [stack.topAnchor constraintEqualToAnchor:content.topAnchor constant:24],
        [stack.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-24],
        [stack.centerXAnchor constraintEqualToAnchor:frame.centerXAnchor],
        [stack.widthAnchor constraintLessThanOrEqualToConstant:640],
        fullWidth,
    ]];
}

- (UIView *)cardForExample:(HomeExample *)example tag:(NSUInteger)tag {
    UILabel *title = [self labelWithText:example.title
                                    font:[Theme fontWithWeight:UIFontWeightBold size:20 textStyle:UIFontTextStyleTitle3]
                                   color:Theme.fogGray];
    UILabel *summary = [self labelWithText:example.summary
                                      font:[Theme fontWithWeight:UIFontWeightRegular
                                                            size:15
                                                       textStyle:UIFontTextStyleBody]
                                     color:Theme.mutedFog];
    UIStackView *chips = [[UIStackView alloc] initWithArrangedSubviews:@[
        [self chipWithText:example.delivery], [self chipWithText:example.insertion], [UIView new]
    ]];
    chips.spacing = 8;

    UIStackView *text = [[UIStackView alloc] initWithArrangedSubviews:@[ title, summary, chips ]];
    text.axis = UILayoutConstraintAxisVertical;
    text.spacing = 8;
    [text setCustomSpacing:14 afterView:summary];
    text.userInteractionEnabled = NO;
    text.translatesAutoresizingMaskIntoConstraints = NO;

    CardButton *card = [[CardButton alloc] init];
    card.tag = (NSInteger)tag;
    card.accessibilityLabel = example.title;
    card.accessibilityHint = example.summary;
    [card addTarget:self action:@selector(openExample:) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:text];
    [NSLayoutConstraint activateConstraints:@[
        [text.topAnchor constraintEqualToAnchor:card.topAnchor constant:24],
        [text.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-20],
        [text.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20],
        [text.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],
    ]];
    return card;
}

- (UIView *)chipWithText:(NSString *)text {
    UILabel *label = [self labelWithText:text
                                    font:[Theme fontWithWeight:UIFontWeightMedium
                                                          size:12
                                                     textStyle:UIFontTextStyleCaption1]
                                   color:Theme.fogGray];
    label.numberOfLines = 1;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    UIView *chip = [[UIView alloc] init];
    chip.backgroundColor = Theme.charcoal;
    chip.layer.cornerRadius = 12;
    chip.layer.cornerCurve = kCACornerCurveContinuous;
    [chip addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [label.topAnchor constraintEqualToAnchor:chip.topAnchor constant:5],
        [label.bottomAnchor constraintEqualToAnchor:chip.bottomAnchor constant:-5],
        [label.leadingAnchor constraintEqualToAnchor:chip.leadingAnchor constant:10],
        [label.trailingAnchor constraintEqualToAnchor:chip.trailingAnchor constant:-10],
    ]];
    return chip;
}

- (UILabel *)labelWithText:(NSString *)text font:(UIFont *)font color:(UIColor *)color {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.font = font;
    label.textColor = color;
    label.numberOfLines = 0;
    label.adjustsFontForContentSizeCategory = YES;
    return label;
}

- (void)openExample:(UIControl *)sender {
    Class viewControllerClass = _examples[(NSUInteger)sender.tag].viewControllerClass;
    [self.navigationController pushViewController:[[viewControllerClass alloc] init] animated:YES];
}

@end
