# Google IMA SSAI

Use this example when Google DAI stitches the ads into the content stream.

## Copy

Copy the `ImaSsai` folder and `Renderer/TruexRendererFactory.{h,m}` with the bridging header, then replace the
[demo-only `adParameters`](#demo-only-adparameters) call and delete `ImaSsaiDemoAdParameters.swift`. Add the
`GoogleInteractiveMediaAds` Swift package. In the [Objective-C app](objc-app.md), copy the `ImaSsai` folder and
delete `ImaSsaiDemoAdParameters.{h,m}` the same way; it needs no factory.

## Flow

1. `ImaSsaiViewController` requests the DAI VOD stream once the view is in the window, with
   `IMAAVPlayerVideoDisplay` on the app's `AVPlayer`.
2. `AD_BREAK_STARTED` / `AD_BREAK_ENDED` track the ad break; playback is linear (no scrubbing) during a break.
3. On `STARTED`, the ad type comes from `ad.adSystem` and the position from `ad.adPodInfo.adPosition`.
4. For TrueX at position 1 or IDVx at any position, the app pauses the stream, remembers the placeholder end
   (`stream time + ad.duration`), and starts `TruexAdRenderer` with the ad's `adParameters`.
5. On `onAdCompleted` with TrueX credit, the app seeks past the current cue point (`endTime + 0.1`). Otherwise, and
   on `onAdError` or `onNoAdsAvailable`, it seeks to the end of the placeholder so the next ad plays.
6. A periodic check seeks over ad breaks that were already played.

DAI has no `discardAdBreak`, so every skip is a stream seek.

## Demo-only `adParameters`

For demo purposes only, `ImaSsaiDemoAdParameters.swift` takes the Infillion ads' `adParameters` from the iOS
sample tags instead of from the ad. Do not use it in production: read `adParameters` from the ad with
`imaSsaiAdParameters(traffickingParameters: ad.traffickingParameters)` (Objective-C:
`ImaSsaiAdParameters(ad.traffickingParameters)`), as noted in `handleAdStarted`.

## Renderer contract

Same as [Plain / Manual CSAI](manual-csai.md#renderer-contract): the renderer options, a strong
renderer reference, hidden system UI while the renderer is active, `onPopupWebsite` in `SFSafariViewController`,
and lifecycle pause/resume.

## Replace in production

- Supply the publisher's DAI content source and video IDs (or live asset key) and network code.
- Read `adParameters` from `ad.traffickingParameters`, and remove `ImaSsaiDemoAdParameters.swift` (`.h` / `.m`).
- Reconcile stream time with content time (`streamManager.contentTime(forStreamTime:)`) for the player UI.
- Snap seeks back to unplayed ad breaks, and test every seek direction and live-window behavior if applicable.
- Add production stream-error retry and telemetry.

## Sample stream configuration

The sample DAI stream uses content source ID `2496857` and video ID `truex-content22-4k`, with a preroll and
three midrolls. Each break has a TrueX ad, an IDVx ad, and two linear ads.
