# Plain / Manual CSAI

Use this example when the app or a publisher-owned ad layer decides when an ad break starts and which ads it
contains.

## Copy

Copy the `ManualCsai` folder, `Resources/manual_ad_break.json`, and `Renderer/TruexRendererFactory.{h,m}` with
the bridging header. The folder does not depend on either IMA example.

## Flow

1. `ManualCsaiViewController` loads `manual_ad_break.json` and starts content in an `AVPlayerViewController`.
2. A periodic time observer detects the reference midroll at 10 seconds, also after a seek past it.
3. The app saves the content position, pauses content, and hides the playback controls.
4. For every Infillion ad in the pod it replaces `${user-id}` in the `vastUrl`, fetches the VAST, and reads the
   `adParameters` JSON (`ManualVastPayload`, see [VAST tag formats](#vast-tag-formats-and-ad-parameters)). Fetching
   at break start gives each break a fresh ad session.
5. The pod plays ad by ad. Linear ads play in the same `AVPlayer`.
6. TrueX at position 1 and IDVx at any position start `TruexAdRenderer` over the player. A TrueX ad at a later
   position plays its placeholder as a linear ad. An Infillion ad without usable `adParameters` is skipped.
7. `onAdFreePod` records TrueX credit. On `onAdCompleted`, credit skips the rest of the pod; otherwise, and on
   `onAdError` or `onNoAdsAvailable`, the next ad plays.
8. After the pod, content is restored at its saved position.

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

`ManualVastPayload` checks for a `truex` companion first, then falls back to `<AdParameters>`. If neither holds a
JSON object, the ad is skipped and the pod continues. The sample fixture uses the companion tag for TrueX and the
generic tag for IDVx, so one break exercises both formats.

## Renderer contract

- The renderer is created by `TruexRendererFactory` with `supportsUserCancelStream` enabled and web view debugging
  in debug builds only. `onUserCancelStream` closes the player screen.
- The view controller keeps a strong reference to the renderer, because the renderer holds its delegate weakly.
- While the renderer is active, the navigation bar, status bar, and home indicator are hidden.
- `onPopupWebsite` pauses the renderer and opens `SFSafariViewController`; the renderer resumes when Safari closes.
- The renderer pauses on `willResignActive`, resumes on `didBecomeActive`, and is stopped after every terminal
  event and when the screen closes.
- Advertising IDs are not set here. The ad server's advertising ID macro should already be in `AdParameters`;
  confirm it during integration certification.

## Replace in production

- Replace the JSON fixture and sample VAST URLs with the publisher's VMAP/VAST or ad-server response.
- Read `adParameters` from the metadata the host ad framework actually delivers.
- Replace the sample content and fallback media.
- Integrate the break detection with the production timeline and persisted playback state.
- Define production retry, telemetry, and renderer-error policy.

## Sample tag configuration

`manual_ad_break.json` uses the iOS TrueX companion tag and the iOS IDVx generic tag with `&ip=158.106.195.210` (Infillion's NYC
office IP), so the requests are filled outside the US and Canada and on CI. Replace or remove it with
publisher-managed geo/IP handling in production.
