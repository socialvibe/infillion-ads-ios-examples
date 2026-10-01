# Objective-C app

`objc-ios-app` is the Objective-C version of `swift-ios-app`, for publishers whose players are written in
Objective-C. Open `objc-ios-app/InfillionAdsExamplesObjC.xcodeproj` and run the `InfillionAdsExamplesObjC` scheme.

- Same examples, flows, sample configuration, and unit-tested rules as the Swift app; only the language changes.
  The [example guides](../README.md#read-one-integration) apply to both apps.
- Each example has the same file names with `.h` / `.m` instead of `.swift`, for example
  `ManualCsai/ManualCsaiViewController.m` or `ImaSsai/ImaSsaiDemoAdParameters.m`.
- The rules are C functions with the same names, starting with a capital letter (for example `CanPlayInteractive`,
  `ShouldDiscardImaCsaiAdBreak`, `ImaSsaiAdParameters`), covered by the same XCTest cases.
- Objective-C sets `TruexAdOptions` on `DefaultOptions()` and passes them to
  `initWithAdParameters:options:delegate:` in each example, so it doesn't need `TruexRendererFactory`.
- Tag fetches are `NSURLSessionDataTask`s, cancelled when the player screen closes.
- It shares the root [Version.xcconfig](../Version.xcconfig) with the Swift app.
