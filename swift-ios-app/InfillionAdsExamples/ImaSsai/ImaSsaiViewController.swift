import AVKit
import GoogleInteractiveMediaAds
import SafariServices
import TruexAdRenderer
import UIKit

/// Google IMA SSAI: a Google DAI VOD stream with stitched ad breaks.
///
/// When IMA starts a TrueX or IDVx placeholder ad, the app pauses the stream and runs `TruexAdRenderer`.
/// Afterwards it seeks past the whole ad break (TrueX credit) or to the end of the placeholder (no credit).
/// DAI has no `discardAdBreak`, so every skip is a stream seek.
final class ImaSsaiViewController: UIViewController {
    // Sample configuration. Replace with publisher-owned DAI content.
    private static let contentSourceId = "2496857"
    private static let videoId = "truex-content22-4k"

    private let player = AVPlayer()
    private let playerViewController = AVPlayerViewController()
    private let adContainerView = UIView()
    private let statusView = StatusView()

    private let adsLoader = IMAAdsLoader(settings: nil)
    private var streamManager: IMAStreamManager?
    private lazy var videoDisplay = IMAAVPlayerVideoDisplay(avPlayer: player)
    private var streamRequested = false
    private var timeObserver: Any?
    private var isPlayingAdBreak = false

    // Keep a strong reference: the renderer holds its delegate weakly and is released otherwise.
    private var truexAdRenderer: TruexAdRenderer?
    private var currentInteractiveType = ImaSsaiAdType.linear
    private var truexAdCreditReceived = false
    private var placeholderEndTime = 0.0
    private var adParametersTask: Task<Void, Never>?

    override var prefersStatusBarHidden: Bool {
        truexAdRenderer != nil
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        truexAdRenderer != nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Google IMA SSAI"
        view.backgroundColor = .black

        playerViewController.player = player
        playerViewController.allowsPictureInPicturePlayback = false
        addChild(playerViewController)
        playerViewController.view.frame = view.bounds
        playerViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(playerViewController.view)
        playerViewController.didMove(toParent: self)

        // IMA draws its ad UI here. Touches pass through to the player.
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
        adsLoader.delegate = self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // IMA requires the ad container to be in the window when the stream is requested.
        if !streamRequested {
            streamRequested = true
            requestStream()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent {
            adParametersTask?.cancel()
            disposeRenderer()
            if let timeObserver {
                player.removeTimeObserver(timeObserver)
            }
            player.pause()
            streamManager?.destroy()
            NotificationCenter.default.removeObserver(self)
        }
    }

    // MARK: - IMA

    private func requestStream() {
        statusView.text = "Requesting DAI stream"
        let displayContainer = IMAAdDisplayContainer(adContainer: adContainerView, viewController: self)
        let request = IMAVODStreamRequest(
            contentSourceID: Self.contentSourceId,
            videoID: Self.videoId,
            adDisplayContainer: displayContainer,
            videoDisplay: videoDisplay,
            userContext: nil
        )
        adsLoader.requestStream(with: request)
    }

    private var currentStreamTime: Double {
        CMTimeGetSeconds(player.currentTime())
    }

    private func seekStream(to seconds: Double) {
        player.seek(
            to: CMTime(seconds: seconds, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }

    /// The stitched stream can't be discarded, so a break that was already played is seeked over.
    private func skipPlayedAdBreak(at streamTime: Double) {
        guard !isPlayingAdBreak, truexAdRenderer == nil,
            let cuepoint = (streamManager?.cuepoints as? [IMACuepoint])?.first(where: {
                $0.isPlayed && $0.startTime <= streamTime && streamTime < $0.endTime
            })
        else {
            return
        }
        seekStream(to: imaSsaiAdBreakSkipTime(adBreakEndStreamTime: cuepoint.endTime))
    }

    private func handleAdStarted(_ ad: IMAAd) {
        let type = classifyImaSsaiAd(adSystem: ad.adSystem)
        let position = ad.adPodInfo.adPosition
        guard canPlayImaSsaiInteractive(type, adPosition: position) else {
            statusView.text = "Ad \(position): linear \(ad.adTitle)"
            return
        }
        player.pause()
        placeholderEndTime = imaSsaiPlaceholderEndTime(adStartStreamTime: currentStreamTime, adDuration: ad.duration)
        statusView.text = "Ad \(position): requesting \(ad.adSystem) adParameters"

        adParametersTask = Task { @MainActor in
            // A production app reads them from the ad:
            // imaSsaiAdParameters(
            //     companions: ad.companionAds.map { ($0.apiFramework, $0.resourceValue) },
            //     traffickingParameters: ad.traffickingParameters
            // )
            let adParameters = await ImaSsaiDemoAdParameters.load(for: type)
            // The screen was closed while the adParameters were loading.
            guard !Task.isCancelled else {
                return
            }
            guard let adParameters else {
                // No usable adParameters: don't start the renderer, continue the pod.
                statusView.text = "Ad \(position): \(ad.adSystem) unavailable, continuing the pod"
                finishInteractiveAd(skipAdBreak: false)
                return
            }
            statusView.text = "Ad \(position): interactive \(ad.adSystem)"
            currentInteractiveType = type
            truexAdCreditReceived = false
            guard let renderer = TruexRendererFactory.renderer(withAdParameters: adParameters, delegate: self) else {
                // No renderer means no delegate events: continue the pod.
                statusView.text = "Ad \(position): renderer unavailable, continuing the pod"
                finishInteractiveAd(skipAdBreak: false)
                return
            }
            truexAdRenderer = renderer
            setRendererActive(true)
            renderer.start(view)
        }
    }

    // MARK: - Interactive ad

    private func finishInteractiveAd(skipAdBreak: Bool) {
        disposeRenderer()
        let streamTime = currentStreamTime
        if skipAdBreak,
            let cuepoint = (streamManager?.cuepoints as? [IMACuepoint])?.first(where: {
                $0.startTime <= streamTime && streamTime < $0.endTime
            })
        {
            statusView.text = "TrueX credit earned: seeking past the ad break"
            seekStream(to: imaSsaiAdBreakSkipTime(adBreakEndStreamTime: cuepoint.endTime))
        } else {
            seekStream(to: placeholderEndTime)
        }
        player.play()
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

extension ImaSsaiViewController: IMAAdsLoaderDelegate {
    func adsLoader(_ loader: IMAAdsLoader, adsLoadedWith adsLoadedData: IMAAdsLoadedData) {
        streamManager = adsLoadedData.streamManager
        streamManager?.delegate = self
        streamManager?.initialize(with: nil)
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            self?.skipPlayedAdBreak(at: CMTimeGetSeconds(time))
        }
    }

    func adsLoader(_ loader: IMAAdsLoader, failedWith adErrorData: IMAAdLoadingErrorData) {
        statusView.text = "Error: DAI stream failed to load (\(adErrorData.adError.message ?? ""))"
    }
}

// MARK: - IMAStreamManagerDelegate

extension ImaSsaiViewController: IMAStreamManagerDelegate {
    func streamManager(_ streamManager: IMAStreamManager, didReceive event: IMAAdEvent) {
        switch event.type {
        case .STREAM_STARTED:
            statusView.text = "Content"
        case .AD_BREAK_STARTED:
            isPlayingAdBreak = true
            playerViewController.requiresLinearPlayback = true
            statusView.text = "Ad break"
        case .AD_BREAK_ENDED:
            isPlayingAdBreak = false
            playerViewController.requiresLinearPlayback = false
            statusView.text = "Content"
        case .STARTED:
            if let ad = event.ad {
                handleAdStarted(ad)
            }
        default:
            break
        }
    }

    func streamManager(_ streamManager: IMAStreamManager, didReceive error: IMAAdError) {
        statusView.text = "Ad error (\(error.message ?? ""))"
    }
}

// MARK: - TruexAdRendererDelegate

extension ImaSsaiViewController: TruexAdRendererDelegate {
    func onAdFreePod() {
        // Remember the reward; act on it in onAdCompleted. IDVx never calls this.
        exampleLog("onAdFreePod")
        truexAdCreditReceived = true
    }

    func onAdCompleted(_ timeSpent: Int) {
        exampleLog("onAdCompleted timeSpent=\(timeSpent)")
        finishInteractiveAd(
            skipAdBreak: shouldSkipImaSsaiAdBreak(currentInteractiveType, earnedCredit: truexAdCreditReceived)
        )
    }

    func onAdError(_ errorMessage: String!) {
        exampleLog("onAdError: \(errorMessage ?? "")")
        finishInteractiveAd(skipAdBreak: false)
    }

    func onNoAdsAvailable() {
        exampleLog("onNoAdsAvailable")
        finishInteractiveAd(skipAdBreak: false)
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

extension ImaSsaiViewController: SFSafariViewControllerDelegate {
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        truexAdRenderer?.resume()
    }
}
