import AVKit
import SafariServices
import TruexAdRenderer
import UIKit

/// Plain / Manual CSAI: the app owns the ad break.
///
/// At the break offset the app pauses content, fetches the Infillion VAST tags, and plays the pod ad by ad.
/// TrueX and IDVx ads run in `TruexAdRenderer`; other ads play as linear video. TrueX credit skips the rest of the pod.
final class ManualCsaiViewController: UIViewController {
    // Sample configuration. Replace with publisher-owned content and ad server data.
    private static let contentUrl = URL(string: "https://ctv.truex.com/assets/reference-app-stream-no-ads-720p.mp4")!
    private static let userId = "ref-app-\(UUID().uuidString)"

    private let player = AVPlayer()
    private let playerViewController = AVPlayerViewController()
    private let statusView = StatusView()
    private let contentItem = AVPlayerItem(url: ManualCsaiViewController.contentUrl)
    private var timeObserver: Any?
    private var adEndObservers: [NSObjectProtocol] = []

    private var adBreak: ManualAdBreak?
    private var adBreakStarted = false
    private var contentResumeTime = CMTime.zero
    private var adParametersByIndex: [Int: [String: Any]] = [:]
    private var adParametersTask: Task<Void, Never>?
    private var currentAdIndex = 0

    // Keep a strong reference: the renderer holds its delegate weakly and is released otherwise.
    private var truexAdRenderer: TruexAdRenderer?
    private var currentInteractiveType = ManualAdType.linear
    private var truexAdCreditReceived = false

    override var prefersStatusBarHidden: Bool {
        truexAdRenderer != nil
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        truexAdRenderer != nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Plain / Manual CSAI"
        view.backgroundColor = .black

        playerViewController.player = player
        addChild(playerViewController)
        playerViewController.view.frame = view.bounds
        playerViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(playerViewController.view)
        playerViewController.didMove(toParent: self)
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

        do {
            adBreak = try ManualAdBreak.loadFromBundle()
        } catch {
            statusView.text = "Error: can't load manual_ad_break.json (\(error.localizedDescription))"
        }
        startContent()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent {
            adParametersTask?.cancel()
            disposeRenderer()
            player.pause()
            if let timeObserver {
                player.removeTimeObserver(timeObserver)
            }
            removeAdEndObservers()
            NotificationCenter.default.removeObserver(self)
        }
    }

    // MARK: - Content

    private func startContent() {
        player.replaceCurrentItem(with: contentItem)
        player.play()
        statusView.text = "Content"

        // A periodic check, unlike a boundary observer, also catches a seek past the break offset.
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self, let adBreak = self.adBreak, !self.adBreakStarted,
                self.player.currentItem === self.contentItem,
                time.seconds >= adBreak.timeOffsetSeconds
            else {
                return
            }
            self.startAdBreak(adBreak)
        }
    }

    // MARK: - Ad break

    private func startAdBreak(_ adBreak: ManualAdBreak) {
        adBreakStarted = true
        contentResumeTime = player.currentTime()
        player.pause()
        playerViewController.showsPlaybackControls = false
        statusView.text = "Ad break \(adBreak.breakId): requesting Infillion ads"

        // Fetch the tags when the break starts, so every break gets a fresh ad session.
        adParametersTask = Task { @MainActor in
            for (index, ad) in adBreak.ads.enumerated() {
                guard !Task.isCancelled else {
                    return
                }
                guard let url = ad.resolvedVastUrl(userId: Self.userId) else {
                    continue
                }
                do {
                    adParametersByIndex[index] = try await ManualVastPayload.load(from: url)
                } catch {
                    exampleLog("No adParameters for \(ad.id): \(error.localizedDescription)")
                }
            }
            // The screen was closed while the tags were loading.
            guard !Task.isCancelled else {
                return
            }
            playAd(at: 0)
        }
    }

    private func playAd(at index: Int) {
        guard let adBreak, index < adBreak.ads.count else {
            endAdBreak()
            return
        }
        currentAdIndex = index
        let ad = adBreak.ads[index]
        let position = index + 1

        if canPlayInteractive(ad.type, adPosition: position) {
            if let adParameters = adParametersByIndex[index] {
                startInteractiveAd(ad, adParameters: adParameters, position: position)
            } else {
                // No usable adParameters: don't start the renderer, continue the pod.
                statusView.text = "Ad \(position): \(ad.adSystem) unavailable, continuing the pod"
                playAd(at: index + 1)
            }
        } else {
            playLinearAd(ad, position: position)
        }
    }

    private func playLinearAd(_ ad: ManualAd, position: Int) {
        statusView.text = "Ad \(position): linear \(ad.id)"
        let item = AVPlayerItem(url: ad.mediaUrl)
        removeAdEndObservers()
        for name in [AVPlayerItem.didPlayToEndTimeNotification, AVPlayerItem.failedToPlayToEndTimeNotification] {
            adEndObservers.append(
                NotificationCenter.default.addObserver(forName: name, object: item, queue: .main) { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.removeAdEndObservers()
                    self.playAd(at: self.currentAdIndex + 1)
                }
            )
        }
        player.replaceCurrentItem(with: item)
        player.play()
    }

    private func endAdBreak() {
        removeAdEndObservers()
        player.replaceCurrentItem(with: contentItem)
        player.seek(to: contentResumeTime, toleranceBefore: .zero, toleranceAfter: .zero)
        player.play()
        playerViewController.showsPlaybackControls = true
        statusView.text = "Content"
    }

    private func removeAdEndObservers() {
        adEndObservers.forEach(NotificationCenter.default.removeObserver)
        adEndObservers.removeAll()
    }

    // MARK: - Interactive ad

    private func startInteractiveAd(_ ad: ManualAd, adParameters: [String: Any], position: Int) {
        statusView.text = "Ad \(position): interactive \(ad.adSystem)"
        currentInteractiveType = ad.type
        truexAdCreditReceived = false
        guard let renderer = TruexRendererFactory.renderer(withAdParameters: adParameters, delegate: self) else {
            // No renderer means no delegate events: continue the pod.
            statusView.text = "Ad \(position): renderer unavailable, continuing the pod"
            playAd(at: currentAdIndex + 1)
            return
        }
        truexAdRenderer = renderer
        setRendererActive(true)
        renderer.start(view)
    }

    private func finishInteractiveAd(skipRemainingAds: Bool) {
        disposeRenderer()
        if skipRemainingAds {
            statusView.text = "TrueX credit earned: skipping the rest of the pod"
            endAdBreak()
        } else {
            playAd(at: currentAdIndex + 1)
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

// MARK: - TruexAdRendererDelegate

extension ManualCsaiViewController: TruexAdRendererDelegate {
    func onAdFreePod() {
        // Remember the reward; act on it in onAdCompleted. IDVx never calls this.
        exampleLog("onAdFreePod")
        truexAdCreditReceived = true
    }

    func onAdCompleted(_ timeSpent: Int) {
        exampleLog("onAdCompleted timeSpent=\(timeSpent)")
        finishInteractiveAd(
            skipRemainingAds: shouldSkipRemainingPod(currentInteractiveType, earnedCredit: truexAdCreditReceived)
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

extension ManualCsaiViewController: SFSafariViewControllerDelegate {
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        truexAdRenderer?.resume()
    }
}
