#import "ImaCsaiViewController.h"

#import <AVKit/AVKit.h>
#import <GoogleInteractiveMediaAds/GoogleInteractiveMediaAds.h>
#import <SafariServices/SafariServices.h>
#import <TruexAdRenderer/TruexAdRenderer.h>

#import "ImaCsaiAdPayload.h"
#import "StatusView.h"

// Sample configuration. Replace with publisher-owned content and ad tags.
static NSString *const kContentUrl = @"https://ctv.truex.com/assets/reference-app-stream-no-ads-720p.mp4";
static NSString *const kVmapResource = @"ima_csai_vmap";

@interface ImaCsaiViewController () <IMAAdsLoaderDelegate,
                                     IMAAdsManagerDelegate,
                                     TruexAdRendererDelegate,
                                     SFSafariViewControllerDelegate,
                                     AVPlayerViewControllerDelegate>
@end

@implementation ImaCsaiViewController {
    AVPlayer *_contentPlayer;
    AVPlayerViewController *_playerViewController;
    UIView *_adContainerView;
    StatusView *_statusView;

    IMAAdsLoader *_adsLoader;
    IMAAdsManager *_adsManager;
    BOOL _adsRequested;
    // Plays the ads in the content player, so the app can seek past a placeholder with a plain AVPlayer seek.
    IMAAVPlayerVideoDisplay *_videoDisplay;
    IMAPictureInPictureProxy *_pictureInPictureProxy;

    // Keep a strong reference: the renderer holds its delegate weakly and is released otherwise.
    TruexAdRenderer *_truexAdRenderer;
    ImaCsaiAdType _currentInteractiveType;
    BOOL _truexAdCreditReceived;
}

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _contentPlayer = [[AVPlayer alloc] init];
        _playerViewController = [[AVPlayerViewController alloc] init];
        _adContainerView = [[UIView alloc] init];
        _statusView = [[StatusView alloc] init];

        IMASettings *settings = [[IMASettings alloc] init];
        // Required by IMA for requests with an IMAAVPlayerVideoDisplay; background audio is not enabled in this app.
        settings.enableBackgroundPlayback = YES;
        _adsLoader = [[IMAAdsLoader alloc] initWithSettings:settings];
        _videoDisplay = [[IMAAVPlayerVideoDisplay alloc] initWithAVPlayer:_contentPlayer];
        // Required by the IMAAVPlayerVideoDisplay request; picture in picture is disabled in this example.
        _pictureInPictureProxy = [[IMAPictureInPictureProxy alloc] initWithAVPlayerViewControllerDelegate:self];
        _currentInteractiveType = ImaCsaiAdTypeLinear;
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
    self.title = @"Google IMA CSAI";
    self.view.backgroundColor = UIColor.blackColor;

    _playerViewController.player = _contentPlayer;
    _playerViewController.allowsPictureInPicturePlayback = NO;
    _playerViewController.delegate = (id<AVPlayerViewControllerDelegate>)_pictureInPictureProxy;
    [self addChildViewController:_playerViewController];
    _playerViewController.view.frame = self.view.bounds;
    _playerViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_playerViewController.view];
    [_playerViewController didMoveToParentViewController:self];

    // IMA draws its ad UI (countdown, "Learn more") here. Touches pass through to the player during content.
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

    [_contentPlayer
        replaceCurrentItemWithPlayerItem:[AVPlayerItem playerItemWithURL:[NSURL URLWithString:kContentUrl]]];
    _adsLoader.delegate = self;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    // IMA requires the ad container to be in the window when ads are requested.
    if (!_adsRequested) {
        _adsRequested = YES;
        [self requestAds];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.isMovingFromParentViewController) {
        [self disposeRenderer];
        [_adsManager destroy];
        [_contentPlayer pause];
        [NSNotificationCenter.defaultCenter removeObserver:self];
    }
}

#pragma mark - IMA

- (void)requestAds {
    NSURL *url = [NSBundle.mainBundle URLForResource:kVmapResource withExtension:@"xml"];
    NSString *vmap = url ? [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil] : nil;
    if (!vmap) {
        _statusView.text = [NSString stringWithFormat:@"Error: can't load %@.xml, playing content", kVmapResource];
        [_contentPlayer play];
        return;
    }
    _statusView.text = @"Requesting ads";
    IMAAdDisplayContainer *displayContainer = [[IMAAdDisplayContainer alloc] initWithAdContainer:_adContainerView
                                                                                  viewController:self];
    IMAAdsRequest *request = [[IMAAdsRequest alloc] initWithAdsResponse:vmap
                                                     adDisplayContainer:displayContainer
                                                   avPlayerVideoDisplay:_videoDisplay
                                                  pictureInPictureProxy:_pictureInPictureProxy
                                                            userContext:nil];
    [_adsLoader requestAdsWithRequest:request];
}

- (void)handleAdStarted:(IMAAd *)ad {
    ImaCsaiAdType type = ClassifyImaCsaiAd(ad.adSystem);
    NSInteger position = ad.adPodInfo.adPosition;
    if (!CanPlayImaCsaiInteractive(type, position)) {
        _statusView.text = [NSString stringWithFormat:@"Ad %ld: linear %@", (long)position, ad.adTitle];
        return;
    }
    // Pause IMA and move the placeholder to its end, so it completes as soon as IMA resumes.
    [_adsManager pause];
    [self skipPlaceholderAd];

    NSDictionary *adParameters = ImaCsaiAdParameters(ad.companionAds, ad.traffickingParameters);
    if (!adParameters) {
        // No usable adParameters: don't start the renderer, continue the pod.
        _statusView.text =
            [NSString stringWithFormat:@"Ad %ld: %@ unavailable, continuing the pod", (long)position, ad.adSystem];
        [_adsManager resume];
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
        [self finishInteractiveAdSkippingRemainingAds:NO];
        return;
    }
    _truexAdRenderer = renderer;
    [self setRendererActive:YES];
    [renderer start:self.view];
}

- (void)skipPlaceholderAd {
    CMTime duration = _contentPlayer.currentItem.duration;
    if (!CMTIME_IS_NUMERIC(duration)) {
        return;
    }
    CMTime end = CMTimeSubtract(duration, CMTimeMake(1, 10));
    [_contentPlayer seekToTime:end toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
}

#pragma mark - Interactive ad

- (void)finishInteractiveAdSkippingRemainingAds:(BOOL)skipRemainingAds {
    [self disposeRenderer];
    if (skipRemainingAds) {
        _statusView.text = @"TrueX credit earned: discarding the rest of the ad break";
        [_adsManager discardAdBreak];
    } else {
        [_adsManager resume];
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

#pragma mark - IMAAdsLoaderDelegate

- (void)adsLoader:(IMAAdsLoader *)loader adsLoadedWithData:(IMAAdsLoadedData *)adsLoadedData {
    _adsManager = adsLoadedData.adsManager;
    _adsManager.delegate = self;
    [_adsManager initializeWithAdsRenderingSettings:nil];
}

- (void)adsLoader:(IMAAdsLoader *)loader failedWithErrorData:(IMAAdLoadingErrorData *)adErrorData {
    _statusView.text =
        [NSString stringWithFormat:@"Ads failed to load (%@), playing content", adErrorData.adError.message];
    [_contentPlayer play];
}

#pragma mark - IMAAdsManagerDelegate

- (void)adsManager:(IMAAdsManager *)adsManager didReceiveAdEvent:(IMAAdEvent *)event {
    if (event.type == kIMAAdEvent_LOADED) {
        [adsManager start];
    } else if (event.type == kIMAAdEvent_STARTED && event.ad) {
        [self handleAdStarted:event.ad];
    }
}

- (void)adsManager:(IMAAdsManager *)adsManager didReceiveAdError:(IMAAdError *)error {
    _statusView.text = [NSString stringWithFormat:@"Ad error (%@), playing content", error.message];
    [_contentPlayer play];
}

- (void)adsManagerDidRequestContentPause:(IMAAdsManager *)adsManager {
    _playerViewController.showsPlaybackControls = NO;
    _adContainerView.userInteractionEnabled = YES;
    [_contentPlayer pause];
}

- (void)adsManagerDidRequestContentResume:(IMAAdsManager *)adsManager {
    _playerViewController.showsPlaybackControls = YES;
    _adContainerView.userInteractionEnabled = NO;
    _statusView.text = @"Content";
    [_contentPlayer play];
}

#pragma mark - TruexAdRendererDelegate

- (void)onAdFreePod {
    // Remember the reward; act on it in onAdCompleted. IDVx never calls this.
    ExampleLog(@"onAdFreePod");
    _truexAdCreditReceived = YES;
}

- (void)onAdCompleted:(NSInteger)timeSpent {
    ExampleLog(@"onAdCompleted timeSpent=%ld", (long)timeSpent);
    [self finishInteractiveAdSkippingRemainingAds:ShouldDiscardImaCsaiAdBreak(_currentInteractiveType,
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
