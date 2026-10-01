import AVKit
import GoogleInteractiveMediaAds
import SafariServices
import TruexAdRenderer
import UIKit

/// Google IMA CSAI: IMA requests and sequences client-side ads.
///
/// When IMA starts a TrueX or IDVx placeholder ad, the app pauses IMA, moves the placeholder to its end, and runs
/// `TruexAdRenderer` with the ad's `traffickingParameters`. TrueX credit discards the rest of the ad break.
final class ImaCsaiViewController: UIViewController {
    // Sample configuration. Replace with publisher-owned content and ad tags.
    private static let contentUrl = URL(string: "https://ctv.truex.com/assets/reference-app-stream-no-ads-720p.mp4")!
    private static let vmapResource = "ima_csai_vmap"

    private let contentPlayer = AVPlayer()
    private let playerViewController = AVPlayerViewController()
    private let adContainerView = UIView()
    private let statusView = StatusView()

    private let adsLoader: IMAAdsLoader = {
        let settings = IMASettings()
        // Required by IMA for requests with an IMAAVPlayerVideoDisplay; background audio is not enabled in this app.
        settings.enableBackgroundPlayback = true
        return IMAAdsLoader(settings: settings)
    }()
    private var adsManager: IMAAdsManager?
    private var adsRequested = false
    // Plays the ads in the content player, so the app can seek past a placeholder with a plain AVPlayer seek.
    private lazy var videoDisplay = IMAAVPlayerVideoDisplay(avPlayer: contentPlayer)
    private lazy var pictureInPictureProxy = IMAPictureInPictureProxy(avPlayerViewControllerDelegate: self)

    // Keep a strong reference: the renderer holds its delegate weakly and is released otherwise.
    private var truexAdRenderer: TruexAdRenderer?
    private var currentInteractiveType = ImaCsaiAdType.linear
    private var truexAdCreditReceived = false

    override var prefersStatusBarHidden: Bool {
        truexAdRenderer != nil
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        truexAdRenderer != nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Google IMA CSAI"
        view.backgroundColor = .black

        playerViewController.player = contentPlayer
        playerViewController.allowsPictureInPicturePlayback = false
        playerViewController.delegate = pictureInPictureProxy
        addChild(playerViewController)
        playerViewController.view.frame = view.bounds
        playerViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(playerViewController.view)
        playerViewController.didMove(toParent: self)

        // IMA draws its ad UI (countdown, "Learn more") here. Touches pass through to the player during content.
        adContainerView.frame = view.bounds
        adContainerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        adContainerView.isUserInteractionEnabled = false
        view.addSubview(adContainerView)
        statusView.install(in: self)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        contentPlayer.replaceCurrentItem(with: AVPlayerItem(url: Self.contentUrl))
        adsLoader.delegate = self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // IMA requires the ad container to be in the window when ads are requested.
        if !adsRequested {
            adsRequested = true
            requestAds()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent {
            disposeRenderer()
            adsManager?.destroy()
            contentPlayer.pause()
            NotificationCenter.default.removeObserver(self)
        }
    }

    // MARK: - IMA

    private func requestAds() {
        guard let url = Bundle.main.url(forResource: Self.vmapResource, withExtension: "xml"),
            let vmap = try? String(contentsOf: url, encoding: .utf8)
        else {
            statusView.text = "Error: can't load \(Self.vmapResource).xml, playing content"
            contentPlayer.play()
            return
        }
        statusView.text = "Requesting ads"
        let displayContainer = IMAAdDisplayContainer(adContainer: adContainerView, viewController: self)
        let request = IMAAdsRequest(
            adsResponse: vmap,
            adDisplayContainer: displayContainer,
            avPlayerVideoDisplay: videoDisplay,
            pictureInPictureProxy: pictureInPictureProxy,
            userContext: nil
        )
        adsLoader.requestAds(with: request)
    }

    private func handleAdStarted(_ ad: IMAAd) {
        let type = classifyImaCsaiAd(adSystem: ad.adSystem)
        let position = ad.adPodInfo.adPosition
        guard canPlayImaCsaiInteractive(type, adPosition: position) else {
            statusView.text = "Ad \(position): linear \(ad.adTitle)"
            return
        }
        // Pause IMA and move the placeholder to its end, so it completes as soon as IMA resumes.
        adsManager?.pause()
        skipPlaceholderAd()

        guard let adParameters = imaCsaiAdParameters(traffickingParameters: ad.traffickingParameters) else {
            // No usable adParameters: don't start the renderer, continue the pod.
            statusView.text = "Ad \(position): \(ad.adSystem) unavailable, continuing the pod"
            adsManager?.resume()
            return
        }
        statusView.text = "Ad \(position): interactive \(ad.adSystem)"
        currentInteractiveType = type
        truexAdCreditReceived = false
        truexAdRenderer = TruexRendererFactory.renderer(withAdParameters: adParameters, delegate: self)
        setRendererActive(true)
        truexAdRenderer?.start(view)
    }

    private func skipPlaceholderAd() {
        guard let duration = contentPlayer.currentItem?.duration, duration.isNumeric else {
            return
        }
        let end = CMTimeSubtract(duration, CMTime(value: 1, timescale: 10))
        contentPlayer.seek(to: end, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    // MARK: - Interactive ad

    private func finishInteractiveAd(skipRemainingAds: Bool) {
        disposeRenderer()
        if skipRemainingAds {
            statusView.text = "TrueX credit earned: discarding the rest of the ad break"
            adsManager?.discardAdBreak()
        } else {
            adsManager?.resume()
        }
    }

    private func disposeRenderer() {
        truexAdRenderer?.stop()
        truexAdRenderer = nil
        setRendererActive(false)
    }

    private func setRendererActive(_ active: Bool) {
        navigationController?.setNavigationBarHidden(active, animated: false)
        statusView.isHidden = active
        setNeedsStatusBarAppearanceUpdate()
        setNeedsUpdateOfHomeIndicatorAutoHidden()
    }

    @objc private func appWillResignActive() {
        truexAdRenderer?.pause()
    }

    @objc private func appDidBecomeActive() {
        truexAdRenderer?.resume()
    }
}

// MARK: - IMAAdsLoaderDelegate

extension ImaCsaiViewController: IMAAdsLoaderDelegate {
    func adsLoader(_ loader: IMAAdsLoader, adsLoadedWith adsLoadedData: IMAAdsLoadedData) {
        adsManager = adsLoadedData.adsManager
        adsManager?.delegate = self
        adsManager?.initialize(with: nil)
    }

    func adsLoader(_ loader: IMAAdsLoader, failedWith adErrorData: IMAAdLoadingErrorData) {
        statusView.text = "Ads failed to load (\(adErrorData.adError.message ?? "")), playing content"
        contentPlayer.play()
    }
}

// MARK: - IMAAdsManagerDelegate

extension ImaCsaiViewController: IMAAdsManagerDelegate {
    func adsManager(_ adsManager: IMAAdsManager, didReceive event: IMAAdEvent) {
        switch event.type {
        case .LOADED:
            adsManager.start()
        case .STARTED:
            if let ad = event.ad {
                handleAdStarted(ad)
            }
        default:
            break
        }
    }

    func adsManager(_ adsManager: IMAAdsManager, didReceive error: IMAAdError) {
        statusView.text = "Ad error (\(error.message ?? "")), playing content"
        contentPlayer.play()
    }

    func adsManagerDidRequestContentPause(_ adsManager: IMAAdsManager) {
        playerViewController.showsPlaybackControls = false
        adContainerView.isUserInteractionEnabled = true
        contentPlayer.pause()
    }

    func adsManagerDidRequestContentResume(_ adsManager: IMAAdsManager) {
        playerViewController.showsPlaybackControls = true
        adContainerView.isUserInteractionEnabled = false
        statusView.text = "Content"
        contentPlayer.play()
    }
}

// MARK: - TruexAdRendererDelegate

extension ImaCsaiViewController: TruexAdRendererDelegate {
    func onAdFreePod() {
        // Remember the reward; act on it in onAdCompleted. IDVx never calls this.
        exampleLog("onAdFreePod")
        truexAdCreditReceived = true
    }

    func onAdCompleted(_ timeSpent: Int) {
        exampleLog("onAdCompleted timeSpent=\(timeSpent)")
        finishInteractiveAd(
            skipRemainingAds: shouldDiscardImaCsaiAdBreak(currentInteractiveType, earnedCredit: truexAdCreditReceived)
        )
    }

    func onAdError(_ errorMessage: String!) {
        exampleLog("onAdError: \(errorMessage ?? "")")
        finishInteractiveAd(skipRemainingAds: false)
    }

    func onNoAdsAvailable() {
        exampleLog("onNoAdsAvailable")
        finishInteractiveAd(skipRemainingAds: false)
    }

    func onUserCancelStream() {
        exampleLog("onUserCancelStream")
        disposeRenderer()
        navigationController?.popViewController(animated: true)
    }

    func onPopupWebsite(_ url: String!) {
        guard let url = URL(string: url ?? "") else {
            return
        }
        truexAdRenderer?.pause()
        let safari = SFSafariViewController(url: url)
        safari.delegate = self
        present(safari, animated: true)
    }

    func onAdStarted() {
        exampleLog("onAdStarted")
    }

    func onOptIn() {
        exampleLog("onOptIn")
    }

    func onOptOut(_ userInitiated: Bool) {
        exampleLog("onOptOut userInitiated=\(userInitiated)")
    }

    func onSkipCardShown() {
        exampleLog("onSkipCardShown")
    }
}

// MARK: - SFSafariViewControllerDelegate

extension ImaCsaiViewController: SFSafariViewControllerDelegate {
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        truexAdRenderer?.resume()
    }
}

// MARK: - AVPlayerViewControllerDelegate

// Required by IMAPictureInPictureProxy; picture in picture is disabled in this example.
extension ImaCsaiViewController: AVPlayerViewControllerDelegate {}
