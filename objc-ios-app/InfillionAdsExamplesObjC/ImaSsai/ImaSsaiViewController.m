#import "ImaSsaiViewController.h"

#import <AVKit/AVKit.h>
#import <GoogleInteractiveMediaAds/GoogleInteractiveMediaAds.h>
#import <SafariServices/SafariServices.h>
#import <TruexAdRenderer/TruexAdRenderer.h>

#import "ImaSsaiAdPayload.h"
#import "ImaSsaiDemoAdParameters.h"
#import "StatusView.h"

// Sample configuration. Replace with publisher-owned DAI content.
static NSString *const kContentSourceId = @"2496857";
static NSString *const kVideoId = @"truex-content22-4k";

@interface ImaSsaiViewController () <IMAAdsLoaderDelegate,
                                     IMAStreamManagerDelegate,
                                     TruexAdRendererDelegate,
                                     SFSafariViewControllerDelegate>
@end

@implementation ImaSsaiViewController {
    AVPlayer *_player;
    AVPlayerViewController *_playerViewController;
    UIView *_adContainerView;
    StatusView *_statusView;

    IMAAdsLoader *_adsLoader;
    IMAStreamManager *_streamManager;
    IMAAVPlayerVideoDisplay *_videoDisplay;
    BOOL _streamRequested;
    id _timeObserver;
    BOOL _isPlayingAdBreak;

    // Keep a strong reference: the renderer holds its delegate weakly and is released otherwise.
    TruexAdRenderer *_truexAdRenderer;
    ImaSsaiAdType _currentInteractiveType;
    BOOL _truexAdCreditReceived;
    double _placeholderEndTime;
    NSURLSessionDataTask *_adParametersTask;
    BOOL _closed;
}

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _player = [[AVPlayer alloc] init];
        _playerViewController = [[AVPlayerViewController alloc] init];
        _adContainerView = [[UIView alloc] init];
        _statusView = [[StatusView alloc] init];
        _adsLoader = [[IMAAdsLoader alloc] initWithSettings:nil];
        _videoDisplay = [[IMAAVPlayerVideoDisplay alloc] initWithAVPlayer:_player];
        _currentInteractiveType = ImaSsaiAdTypeLinear;
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
    self.title = @"Google IMA SSAI";
    self.view.backgroundColor = UIColor.blackColor;

    _playerViewController.player = _player;
    _playerViewController.allowsPictureInPicturePlayback = NO;
    [self addChildViewController:_playerViewController];
    _playerViewController.view.frame = self.view.bounds;
    _playerViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_playerViewController.view];
    [_playerViewController didMoveToParentViewController:self];

    // IMA draws its ad UI here. Touches pass through to the player.
    _adContainerView.frame = self.view.bounds;
    _adContainerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _adContainerView.userInteractionEnabled = NO;
    [self.view addSubview:_adContainerView];
    [_statusView installInViewController:self];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(appWillResignActive)
                                               name:UIApplicationWillResignActiveNotification
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(appDidBecomeActive)
                                               name:UIApplicationDidBecomeActiveNotification
                                             object:nil];
    _adsLoader.delegate = self;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    // IMA requires the ad container to be in the window when the stream is requested.
    if (!_streamRequested) {
        _streamRequested = YES;
        [self requestStream];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.isMovingFromParentViewController) {
        _closed = YES;
        [_adParametersTask cancel];
        [self disposeRenderer];
        if (_timeObserver) {
            [_player removeTimeObserver:_timeObserver];
        }
        [_player pause];
        [_streamManager destroy];
        [NSNotificationCenter.defaultCenter removeObserver:self];
    }
}

#pragma mark - IMA

- (void)requestStream {
    _statusView.text = @"Requesting DAI stream";
    IMAAdDisplayContainer *displayContainer = [[IMAAdDisplayContainer alloc] initWithAdContainer:_adContainerView
                                                                                  viewController:self];
    IMAVODStreamRequest *request = [[IMAVODStreamRequest alloc] initWithContentSourceID:kContentSourceId
                                                                                videoID:kVideoId
                                                                     adDisplayContainer:displayContainer
                                                                           videoDisplay:_videoDisplay
                                                                            userContext:nil];
    [_adsLoader requestStreamWithRequest:request];
}

- (double)currentStreamTime {
    return CMTimeGetSeconds(_player.currentTime);
}

- (void)seekStreamTo:(double)seconds {
    [_player seekToTime:CMTimeMakeWithSeconds(seconds, 600) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
}

- (nullable IMACuepoint *)cuepointAt:(double)streamTime playedOnly:(BOOL)playedOnly {
    for (IMACuepoint *cuepoint in _streamManager.cuepoints) {
        if (playedOnly && !cuepoint.isPlayed) {
            continue;
        }
        if (cuepoint.startTime <= streamTime && streamTime < cuepoint.endTime) {
            return cuepoint;
        }
    }
    return nil;
}

/// The stitched stream can't be discarded, so a break that was already played is seeked over.
- (void)skipPlayedAdBreakAt:(double)streamTime {
    if (_isPlayingAdBreak || _truexAdRenderer) {
        return;
    }
    IMACuepoint *cuepoint = [self cuepointAt:streamTime playedOnly:YES];
    if (cuepoint) {
        [self seekStreamTo:ImaSsaiAdBreakSkipTime(cuepoint.endTime)];
    }
}

- (void)handleAdStarted:(IMAAd *)ad {
    ImaSsaiAdType type = ClassifyImaSsaiAd(ad.adSystem);
    NSInteger position = ad.adPodInfo.adPosition;
    if (!CanPlayImaSsaiInteractive(type, position)) {
        _statusView.text = [NSString stringWithFormat:@"Ad %ld: linear %@", (long)position, ad.adTitle];
        return;
    }
    [_player pause];
    _placeholderEndTime = ImaSsaiPlaceholderEndTime(self.currentStreamTime, ad.duration);
    _statusView.text = [NSString stringWithFormat:@"Ad %ld: requesting %@ adParameters", (long)position, ad.adSystem];

    // A production app reads them from the ad: ImaSsaiAdParameters(ad.traffickingParameters)
    _adParametersTask = [ImaSsaiDemoAdParameters loadForType:type
                                                  completion:^(NSDictionary *adParameters) {
                                                      // The screen was closed while the adParameters were loading.
                                                      if (self->_closed) {
                                                          return;
                                                      }
                                                      [self startInteractiveAd:ad
                                                                          type:type
                                                                      position:position
                                                                  adParameters:adParameters];
                                                  }];
}

- (void)startInteractiveAd:(IMAAd *)ad
                      type:(ImaSsaiAdType)type
                  position:(NSInteger)position
              adParameters:(nullable NSDictionary *)adParameters {
    if (!adParameters) {
        // No usable adParameters: don't start the renderer, continue the pod.
        _statusView.text =
            [NSString stringWithFormat:@"Ad %ld: %@ unavailable, continuing the pod", (long)position, ad.adSystem];
        [self finishInteractiveAdSkippingAdBreak:NO];
        return;
    }
    _statusView.text = [NSString stringWithFormat:@"Ad %ld: interactive %@", (long)position, ad.adSystem];
    _currentInteractiveType = type;
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
        [self finishInteractiveAdSkippingAdBreak:NO];
        return;
    }
    _truexAdRenderer = renderer;
    [self setRendererActive:YES];
    [renderer start:self.view];
}

#pragma mark - Interactive ad

- (void)finishInteractiveAdSkippingAdBreak:(BOOL)skipAdBreak {
    [self disposeRenderer];
    IMACuepoint *cuepoint = skipAdBreak ? [self cuepointAt:self.currentStreamTime playedOnly:NO] : nil;
    if (cuepoint) {
        _statusView.text = @"TrueX credit earned: seeking past the ad break";
        [self seekStreamTo:ImaSsaiAdBreakSkipTime(cuepoint.endTime)];
    } else {
        [self seekStreamTo:_placeholderEndTime];
    }
    [_player play];
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

#pragma mark - IMAAdsLoaderDelegate

- (void)adsLoader:(IMAAdsLoader *)loader adsLoadedWithData:(IMAAdsLoadedData *)adsLoadedData {
    _streamManager = adsLoadedData.streamManager;
    _streamManager.delegate = self;
    [_streamManager initializeWithAdsRenderingSettings:nil];
    __weak typeof(self) weakSelf = self;
    _timeObserver = [_player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(0.5, 600)
                                                          queue:dispatch_get_main_queue()
                                                     usingBlock:^(CMTime time) {
                                                         [weakSelf skipPlayedAdBreakAt:CMTimeGetSeconds(time)];
                                                     }];
}

- (void)adsLoader:(IMAAdsLoader *)loader failedWithErrorData:(IMAAdLoadingErrorData *)adErrorData {
    _statusView.text =
        [NSString stringWithFormat:@"Error: DAI stream failed to load (%@)", adErrorData.adError.message];
}

#pragma mark - IMAStreamManagerDelegate

- (void)streamManager:(IMAStreamManager *)streamManager didReceiveAdEvent:(IMAAdEvent *)event {
    switch (event.type) {
        case kIMAAdEvent_STREAM_STARTED:
            _statusView.text = @"Content";
            break;
        case kIMAAdEvent_AD_BREAK_STARTED:
            _isPlayingAdBreak = YES;
            _playerViewController.requiresLinearPlayback = YES;
            _statusView.text = @"Ad break";
            break;
        case kIMAAdEvent_AD_BREAK_ENDED:
            _isPlayingAdBreak = NO;
            _playerViewController.requiresLinearPlayback = NO;
            _statusView.text = @"Content";
            break;
        case kIMAAdEvent_STARTED:
            if (event.ad) {
                [self handleAdStarted:event.ad];
            }
            break;
        default:
            break;
    }
}

- (void)streamManager:(IMAStreamManager *)streamManager didReceiveAdError:(IMAAdError *)error {
    _statusView.text = [NSString stringWithFormat:@"Ad error (%@)", error.message];
}

#pragma mark - TruexAdRendererDelegate

- (void)onAdFreePod {
    // Remember the reward; act on it in onAdCompleted. IDVx never calls this.
    ExampleLog(@"onAdFreePod");
    _truexAdCreditReceived = YES;
}

- (void)onAdCompleted:(NSInteger)timeSpent {
    ExampleLog(@"onAdCompleted timeSpent=%ld", (long)timeSpent);
    [self finishInteractiveAdSkippingAdBreak:ShouldSkipImaSsaiAdBreak(_currentInteractiveType, _truexAdCreditReceived)];
}

- (void)onAdError:(NSString *)errorMessage {
    ExampleLog(@"onAdError: %@", errorMessage);
    [self finishInteractiveAdSkippingAdBreak:NO];
}

- (void)onNoAdsAvailable {
    ExampleLog(@"onNoAdsAvailable");
    [self finishInteractiveAdSkippingAdBreak:NO];
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
