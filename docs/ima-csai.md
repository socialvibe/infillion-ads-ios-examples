# Google IMA CSAI

Use this example when Google IMA requests and sequences client-side ads (VAST/VMAP) for an `AVPlayer` app.

## Flow

1. `ImaCsaiViewController` requests ads with the bundled VMAP once the view is in the window (IMA requires the ad
   container to be attached).
2. The request uses `IMAAVPlayerVideoDisplay` on the content player, so IMA plays ads in the app's own `AVPlayer`.
   IMA requires `IMASettings.enableBackgroundPlayback` for this request type; background audio is not enabled in
   the app.
3. On `STARTED`, the ad type comes from `ad.adSystem` and the position from `ad.adPodInfo.adPosition`.
4. For TrueX at position 1 or IDVx at any position, the app pauses IMA, seeks the player to the end of the
   placeholder, and starts `TruexAdRenderer` with the ad's `adParameters`: the `truex` companion in
   `ad.companionAds` first, then `ad.traffickingParameters` (see
   [VAST tag formats and ad parameters](../README.md#vast-tag-formats-and-ad-parameters)). Without usable
   `adParameters` it resumes IMA, which continues the pod.
5. On `onAdCompleted` with TrueX credit, `adsManager.discardAdBreak()` skips the rest of the break. Otherwise, and
   on `onAdError` or `onNoAdsAvailable`, `adsManager.resume()` finishes the placeholder and continues the pod.
6. IMA requests content resume after the break and the app resumes content.

Because the placeholder plays in the app's `AVPlayer`, moving past it is a plain `AVPlayer` seek; no access to IMA
internals is needed.

IMA leaves `ad.companionAds` empty for client-side ads, so with IMA CSAI the `adParameters` always come from
`ad.traffickingParameters`: use the generic tags (`/vast/generic`, `/vast/idvx/generic`).

## Renderer contract

Same as [Plain / Manual CSAI](manual-csai.md#renderer-contract): the renderer options, a strong
renderer reference, hidden system UI while the renderer is active, `onPopupWebsite` in `SFSafariViewController`,
and lifecycle pause/resume.

## Replace in production

- Replace the bundled VMAP with the publisher's ad tag (`IMAAdsRequest(adTagUrl:...)`).
- Configure `IMASettings` and `IMAAdsRenderingSettings` for the publisher (language, PPID, consent).
- Test every pod shape: TrueX first, IDVx in the middle, Infillion ads without fill.
- Define production retry and telemetry for ad errors.

## Sample tag configuration

`ima_csai_vmap.xml` has a preroll and a midroll at 1:00. Each break wraps the iOS TrueX tag, the iOS IDVx tag,
and one linear ad. The tags include `&ip=158.106.195.210` (Infillion's NYC office IP), so the requests are
filled outside the US and Canada and on CI.
