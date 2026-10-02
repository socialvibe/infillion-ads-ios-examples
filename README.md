# Infillion Ads - iOS Examples

> Contributing to this repository? Build, test, code style, and release rules are in
> [CONTRIBUTING.md](CONTRIBUTING.md). The rest of this README is for publishers using the examples.

> [!IMPORTANT]
> These apps are runnable demos. For the full iOS integration guide, see the
> [official iOS integration documentation](https://socialvibe.github.io/infillion-ads-integration-docs/platforms/ios/).

Two iOS reference apps, one in Swift (`swift-ios-app`) and one in Objective-C (`objc-ios-app`), demonstrating the
same three complete ways to add Infillion interactive ads (TrueX and IDVx) to an `AVPlayer` app with
`TruexAdRenderer-iOS`:

| Example | Ad source | Ad break behavior |
| --- | --- | --- |
| **Plain / Manual CSAI** | Bundled JSON fixture | The host app schedules and plays the ad pod. |
| **Google IMA CSAI** | Bundled VMAP | Google IMA requests and sequences client-side ads. |
| **Google IMA SSAI** | Google DAI VOD request | Google DAI returns one stream with stitched ad breaks. |

The examples intentionally duplicate their player, ad, and `TruexAdRenderer` code. Choose one example and read
it from top to bottom without tracing a shared framework. Both apps have the same examples, flows, sample
configuration, and unit tests; only the language differs. The Swift app's only shared integration file is the
small Objective-C `TruexRendererFactory`, which Swift needs to pass `TruexAdOptions`.

## TrueX and IDVx

Both formats use the same renderer and are started the same way, but they differ in how the viewer enters the
experience and what happens afterward:

| | TrueX | IDVx |
| --- | --- | --- |
| Entry | Opt-in from a choice card | Starts directly, no choice card |
| Pod position | Interactive only as the **first** ad in a pod; elsewhere it plays as a normal linear ad | Any position |
| Reward | `onAdFreePod`: the viewer earned the rest of the pod | None, `onAdFreePod` is never called |
| After `onAdCompleted` | Skip the rest of the pod if `onAdFreePod` was called, otherwise continue it | Always continue the pod |

If a TrueX viewer doesn't opt in, or an interactive ad is unavailable, the publisher's normal ad flow
continues. See [What are Infillion Ads?](https://socialvibe.github.io/infillion-ads-integration-docs/overview/what-are-infillion-ads)
for broader product context.

## Integration flow

Publishers:

- Get TrueX and IDVx tags (VAST URLs) from their Infillion contact. Placements are per platform, so iOS uses its
  own tags.
- Target those tags in the publisher ad server, CSAI, or SSAI stack.
- Confirm the tag reaches the app: ad system `trueX` / `IDVx` and the `adParameters` JSON.

Every example follows the same flow:

1. Add `TruexAdRenderer-iOS` and the player or ad SDK dependencies.
2. Detect an Infillion ad from its ad system (`trueX` or `IDVx`, compared case-insensitively).
3. Read `adParameters` from the ad: the `truex` companion first, then `<AdParameters>` (see
   [VAST tag formats and ad parameters](#vast-tag-formats-and-ad-parameters)). If neither holds a JSON object, don't
   start the renderer and continue the pod.
4. Pause playback and move past the placeholder media.
5. Create the renderer with `initWithAdParameters:options:delegate:` and call `start(_:)` with a view above the
   player. Keep a strong reference to it.
6. For TrueX, treat `onAdFreePod` as the reward; act on it in `onAdCompleted`.
7. On `onAdCompleted`, skip the rest of the pod if the reward was earned, otherwise continue the pod. On
   `onAdError` or `onNoAdsAvailable`, continue the pod. On `onUserCancelStream`, leave the player.
8. On `onPopupWebsite`, pause the renderer, show the page in `SFSafariViewController`, and resume afterwards.
9. Pause and resume the renderer with the app lifecycle, and `stop()` it after a terminal event.

## VAST tag formats and ad parameters

Depending on the publisher's ad serving setup, Infillion tags deliver `adParameters` in one of two formats:

1. **Companion tag** (TrueX `/vast/companion`, IDVx `/vast/idvx/companion`): a base64 JSON `data:` URL inside
   `<Companion apiFramework="truex"><StaticResource creativeType="application/json">`:

   ```xml
   <Creative id="super_tag">
     <CompanionAds required="all">
       <Companion id="super_tag" width="960" height="540" apiFramework="truex">
         <StaticResource creativeType="application/json">
           <![CDATA[data:application/json;base64,eyJ1c2VyX2lkIjoi...]]>
         </StaticResource>
       </Companion>
     </CompanionAds>
   </Creative>
   ```

2. **Generic tag** (TrueX `/vast/generic`, IDVx `/vast/idvx/generic`): the JSON directly in `<Linear><AdParameters>`:

   ```xml
   <Creative id="placeholder_video">
     <Linear>
       <Duration>00:00:30</Duration>
       <AdParameters><![CDATA[{"user_id":"...", ...}]]></AdParameters>
       <MediaFiles>...</MediaFiles>
     </Linear>
   </Creative>
   ```

Every example resolves `adParameters` the same way: the `truex` companion first, then `<AdParameters>`. Only the
place where the ad framework exposes them differs:

| Example | `<StaticResource>` of the `truex` companion | `<AdParameters>` |
| --- | --- | --- |
| Plain / Manual CSAI | parsed from the fetched VAST | parsed from the fetched VAST |
| Google IMA CSAI | `ad.companionAds` (`apiFramework`, `resourceValue`) | `ad.traffickingParameters` |
| Google IMA SSAI | `ad.companionAds` (`apiFramework`, `resourceValue`) | `ad.traffickingParameters` |

Google IMA fills `ad.companionAds` only for DAI streams; it is empty for client-side ads. With IMA CSAI, use the
generic tags.

## `TruexAdOptions` in Swift and Objective-C

Both apps create the renderer with the same options:

- `supportsUserCancelStream` is enabled, so leaving from the choice card fires `onUserCancelStream`.
- `enableWebViewDebugging` is enabled in debug builds only.
- `appId` defaults to the bundle identifier.

Objective-C sets them on `DefaultOptions()` and passes them to `initWithAdParameters:options:delegate:` in each
example. Swift can't import the `TruexAdOptions` C struct, so the Swift app creates the renderer through
[`TruexRendererFactory`](swift-ios-app/InfillionAdsExamples/Renderer/TruexRendererFactory.m), exposed with a
bridging header.

## Run the examples

### Requirements

- Xcode 16 or newer
- An iOS Simulator runtime (or a device) running iOS 15.6 or newer
- Network access to the sample media, Google IMA, and the TrueX renderer Swift package

### Xcode

1. Open `swift-ios-app/InfillionAdsExamples.xcodeproj` (Swift) or `objc-ios-app/InfillionAdsExamplesObjC.xcodeproj`
   (Objective-C).
2. Select the `InfillionAdsExamples` or `InfillionAdsExamplesObjC` scheme and an iPhone simulator.
3. Run, then pick an example. The two apps have different bundle IDs, so both can be installed side by side.

Each example plays content and shows its current state (content, ad request, linear ad, interactive ad,
recovery, or error) in the upper-left status panel, and logs it with the `[InfillionAdsExamples]` prefix.

## Sample configuration

Sample URLs and DAI identifiers are deliberately visible near the top of each example. Replace them with
publisher-owned configuration in a real integration.

- iOS TrueX placement `22c36d3926383ba62994809a60b4649e3ced1070` and iOS IDVx placement
  `132f66121635ac312e42f1eb018081d50d10fe2a` on `get.truex.com`, as generic tags (`/vast/generic`,
  `/vast/idvx/generic`) and, for TrueX in Manual CSAI, as a companion tag (`/vast/companion`).
- Test IP parameter (`&ip=158.106.195.210`): Infillion's NYC office IP address is included on the sample tags so
  ads are filled during development and on CI. The TrueX ad server currently serves ads in the US and Canada
  only. Replace it with publisher-managed geo/IP handling in production.
- Google DAI sample content source ID `2496857` and video ID `truex-content22-4k`.

No credentials, signing keys, or production publisher configuration are included.

## Read one integration

- [Plain / Manual CSAI](docs/manual-csai.md)
- [Google IMA CSAI](docs/ima-csai.md)
- [Google IMA SSAI](docs/ima-ssai.md)
