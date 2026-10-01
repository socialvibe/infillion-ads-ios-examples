#import "ManualCsaiViewController.h"

#import <AVKit/AVKit.h>
#import <SafariServices/SafariServices.h>
#import <TruexAdRenderer/TruexAdRenderer.h>

#import "ManualAdBreak.h"
#import "ManualVastPayload.h"
#import "StatusView.h"

// Sample configuration. Replace with publisher-owned content and ad server data.
static NSString *const kContentUrl = @"https://ctv.truex.com/assets/reference-app-stream-no-ads-720p.mp4";

@interface ManualCsaiViewController () <TruexAdRendererDelegate, SFSafariViewControllerDelegate>
@end

@implementation ManualCsaiViewController {
    NSString *_userId;
    AVPlayer *_player;
    AVPlayerViewController *_playerViewController;
    StatusView *_statusView;
    AVPlayerItem *_contentItem;
    id _timeObserver;
    NSMutableArray<id<NSObject>> *_adEndObservers;

    ManualAdBreak *_adBreak;
    BOOL _adBreakStarted;
    CMTime _contentResumeTime;
    NSMutableDictionary<NSNumber *, NSDictionary *> *_adParametersByIndex;
    NSMutableArray<NSURLSessionDataTask *> *_adParametersTasks;
    BOOL _closed;
    NSInteger _currentAdIndex;

    // Keep a strong reference: the renderer holds its delegate weakly and is released otherwise.
    TruexAdRenderer *_truexAdRenderer;
    ManualAdType _currentInteractiveType;
    BOOL _truexAdCreditReceived;
}

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _userId = [@"ref-app-" stringByAppendingString:NSUUID.UUID.UUIDString];
        _player = [[AVPlayer alloc] init];
        _playerViewController = [[AVPlayerViewController alloc] init];
        _statusView = [[StatusView alloc] init];
        _contentItem = [AVPlayerItem playerItemWithURL:[NSURL URLWithString:kContentUrl]];
        _adEndObservers = [NSMutableArray array];
        _contentResumeTime = kCMTimeZero;
        _adParametersByIndex = [NSMutableDictionary dictionary];
        _adParametersTasks = [NSMutableArray array];
        _currentInteractiveType = ManualAdTypeLinear;
    }
    return self;
}

- (BOOL)prefersStatusBarHidden {
    return _truexAdRenderer != nil;
}

- (BOOL)prefersHomeIndicatorAutoHidden {
    return _truexAdRenderer != nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Plain / Manual CSAI";
    self.view.backgroundColor = UIColor.blackColor;

    _playerViewController.player = _player;
    [self addChildViewController:_playerViewController];
    _playerViewController.view.frame = self.view.bounds;
    _playerViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_playerViewController.view];
    [_playerViewController didMoveToParentViewController:self];
    [_statusView installInViewController:self];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(appWillResignActive)
                                               name:UIApplicationWillResignActiveNotification
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(appDidBecomeActive)
                                               name:UIApplicationDidBecomeActiveNotification
                                             object:nil];

    NSError *error = nil;
    _adBreak = [ManualAdBreak loadFromBundleWithError:&error];
    if (!_adBreak) {
        _statusView.text =
            [NSString stringWithFormat:@"Error: can't load manual_ad_break.json (%@)", error.localizedDescription];
    }
    [self startContent];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.isMovingFromParentViewController) {
        _closed = YES;
        for (NSURLSessionDataTask *task in _adParametersTasks) {
            [task cancel];
        }
        [self disposeRenderer];
        [_player pause];
        if (_timeObserver) {
            [_player removeTimeObserver:_timeObserver];
        }
        [self removeAdEndObservers];
        [NSNotificationCenter.defaultCenter removeObserver:self];
    }
}

#pragma mark - Content

- (void)startContent {
    [_player replaceCurrentItemWithPlayerItem:_contentItem];
    [_player play];
    _statusView.text = @"Content";

    // A periodic check, unlike a boundary observer, also catches a seek past the break offset.
    __weak typeof(self) weakSelf = self;
    _timeObserver = [_player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(0.5, 600)
                                                          queue:dispatch_get_main_queue()
                                                     usingBlock:^(CMTime time) {
                                                         [weakSelf checkAdBreakAtTime:time];
                                                     }];
}

- (void)checkAdBreakAtTime:(CMTime)time {
    if (!_adBreak || _adBreakStarted || _player.currentItem != _contentItem) {
        return;
    }
    if (CMTimeGetSeconds(time) >= _adBreak.timeOffsetSeconds) {
        [self startAdBreak];
    }
}

#pragma mark - Ad break

- (void)startAdBreak {
    _adBreakStarted = YES;
    _contentResumeTime = _player.currentTime;
    [_player pause];
    _playerViewController.showsPlaybackControls = NO;
    _statusView.text = [NSString stringWithFormat:@"Ad break %@: requesting Infillion ads", _adBreak.breakId];

    // Fetch the tags when the break starts, so every break gets a fresh ad session.
    dispatch_group_t group = dispatch_group_create();
    [_adBreak.ads enumerateObjectsUsingBlock:^(ManualAd *ad, NSUInteger index, BOOL *stop) {
        NSURL *url = [ad resolvedVastUrlWithUserId:self->_userId];
        if (!url) {
            return;
        }
        dispatch_group_enter(group);
        NSURLSessionDataTask *task =
            [ManualVastPayload loadFromURL:url
                                completion:^(NSDictionary *adParameters, NSError *error) {
                                    if (adParameters) {
                                        self->_adParametersByIndex[@(index)] = adParameters;
                                    } else {
                                        ExampleLog(@"No adParameters for %@: %@", ad.adId, error.localizedDescription);
                                    }
                                    dispatch_group_leave(group);
                                }];
        [self->_adParametersTasks addObject:task];
    }];
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        // The screen was closed while the tags were loading.
        if (self->_closed) {
            return;
        }
        [self playAdAtIndex:0];
    });
}

- (void)playAdAtIndex:(NSInteger)index {
    if (index >= (NSInteger)_adBreak.ads.count) {
        [self endAdBreak];
        return;
    }
    _currentAdIndex = index;
    ManualAd *ad = _adBreak.ads[(NSUInteger)index];
    NSInteger position = index + 1;

    if (CanPlayInteractive(ad.type, position)) {
        NSDictionary *adParameters = _adParametersByIndex[@(index)];
        if (adParameters) {
            [self startInteractiveAd:ad adParameters:adParameters position:position];
        } else {
            // No usable adParameters: don't start the renderer, continue the pod.
            _statusView.text =
                [NSString stringWithFormat:@"Ad %ld: %@ unavailable, continuing the pod", (long)position, ad.adSystem];
            [self playAdAtIndex:index + 1];
        }
    } else {
        [self playLinearAd:ad position:position];
    }
}

- (void)playLinearAd:(ManualAd *)ad position:(NSInteger)position {
    _statusView.text = [NSString stringWithFormat:@"Ad %ld: linear %@", (long)position, ad.adId];
    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:ad.mediaUrl];
    [self removeAdEndObservers];
    __weak typeof(self) weakSelf = self;
    for (NSNotificationName name in @[
             AVPlayerItemDidPlayToEndTimeNotification,
             AVPlayerItemFailedToPlayToEndTimeNotification,
         ]) {
        id observer = [NSNotificationCenter.defaultCenter addObserverForName:name
                                                                      object:item
                                                                       queue:NSOperationQueue.mainQueue
                                                                  usingBlock:^(NSNotification *notification) {
                                                                      [weakSelf linearAdEnded];
                                                                  }];
        [_adEndObservers addObject:observer];
    }
    [_player replaceCurrentItemWithPlayerItem:item];
    [_player play];
}

- (void)linearAdEnded {
    [self removeAdEndObservers];
    [self playAdAtIndex:_currentAdIndex + 1];
}

- (void)endAdBreak {
    [self removeAdEndObservers];
    [_player replaceCurrentItemWithPlayerItem:_contentItem];
    [_player seekToTime:_contentResumeTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
    [_player play];
    _playerViewController.showsPlaybackControls = YES;
    _statusView.text = @"Content";
}

- (void)removeAdEndObservers {
    for (id observer in _adEndObservers) {
        [NSNotificationCenter.defaultCenter removeObserver:observer];
    }
    [_adEndObservers removeAllObjects];
}

#pragma mark - Interactive ad

- (void)startInteractiveAd:(ManualAd *)ad adParameters:(NSDictionary *)adParameters position:(NSInteger)position {
    _statusView.text = [NSString stringWithFormat:@"Ad %ld: interactive %@", (long)position, ad.adSystem];
    _currentInteractiveType = ad.type;
    _truexAdCreditReceived = NO;

    TruexAdOptions options = DefaultOptions();
    options.supportsUserCancelStream = YES;
#if DEBUG
    options.enableWebViewDebugging = YES;
#endif
    TruexAdRenderer *renderer = [[TruexAdRenderer alloc] initWithAdParameters:adParameters
                                                                      options:options
                                                                     delegate:self];
    if (!renderer) {
        // No renderer means no delegate events: continue the pod.
        _statusView.text =
            [NSString stringWithFormat:@"Ad %ld: renderer unavailable, continuing the pod", (long)position];
        [self playAdAtIndex:_currentAdIndex + 1];
        return;
    }
    _truexAdRenderer = renderer;
    [self setRendererActive:YES];
    [renderer start:self.view];
}

- (void)finishInteractiveAdSkippingRemainingAds:(BOOL)skipRemainingAds {
    [self disposeRenderer];
    if (skipRemainingAds) {
        _statusView.text = @"TrueX credit earned: skipping the rest of the pod";
        [self endAdBreak];
    } else {
        [self playAdAtIndex:_currentAdIndex + 1];
    }
}

- (void)disposeRenderer {
    [_truexAdRenderer stop];
    _truexAdRenderer = nil;
    [self setRendererActive:NO];
}

- (void)setRendererActive:(BOOL)active {
    [self.navigationController setNavigationBarHidden:active animated:NO];
    _statusView.hidden = active;
    [self setNeedsStatusBarAppearanceUpdate];
    [self setNeedsUpdateOfHomeIndicatorAutoHidden];
}

- (void)appWillResignActive {
    [_truexAdRenderer pause];
}

- (void)appDidBecomeActive {
    [_truexAdRenderer resume];
}

#pragma mark - TruexAdRendererDelegate

- (void)onAdFreePod {
    // Remember the reward; act on it in onAdCompleted. IDVx never calls this.
    ExampleLog(@"onAdFreePod");
    _truexAdCreditReceived = YES;
}

- (void)onAdCompleted:(NSInteger)timeSpent {
    ExampleLog(@"onAdCompleted timeSpent=%ld", (long)timeSpent);
    [self finishInteractiveAdSkippingRemainingAds:ShouldSkipRemainingPod(_currentInteractiveType,
                                                                         _truexAdCreditReceived)];
}

- (void)onAdError:(NSString *)errorMessage {
    ExampleLog(@"onAdError: %@", errorMessage);
    [self finishInteractiveAdSkippingRemainingAds:NO];
}

- (void)onNoAdsAvailable {
    ExampleLog(@"onNoAdsAvailable");
    [self finishInteractiveAdSkippingRemainingAds:NO];
}

- (void)onUserCancelStream {
    ExampleLog(@"onUserCancelStream");
    [self disposeRenderer];
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)onPopupWebsite:(NSString *)url {
    NSURL *websiteUrl = [NSURL URLWithString:url ?: @""];
    if (!websiteUrl) {
        return;
    }
    [_truexAdRenderer pause];
    SFSafariViewController *safari = [[SFSafariViewController alloc] initWithURL:websiteUrl];
    safari.delegate = self;
    [self presentViewController:safari animated:YES completion:nil];
}

- (void)onAdStarted {
    ExampleLog(@"onAdStarted");
}

- (void)onOptIn {
    ExampleLog(@"onOptIn");
}

- (void)onOptOut:(BOOL)userInitiated {
    ExampleLog(@"onOptOut userInitiated=%@", userInitiated ? @"true" : @"false");
}

- (void)onSkipCardShown {
    ExampleLog(@"onSkipCardShown");
}

#pragma mark - SFSafariViewControllerDelegate

- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller {
    [_truexAdRenderer resume];
}

@end
