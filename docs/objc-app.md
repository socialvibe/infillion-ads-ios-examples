# Proposed Objective-C app

A follow-up app, `objc-ios-app`, will port the three Swift examples to Objective-C for publishers whose players are
written in Objective-C.

- Same examples, flows, sample configuration, and unit-tested rules as `swift-ios-app`; only the language changes.
- Objective-C passes `TruexAdOptions` directly to `initWithAdParameters:options:delegate:`, so it doesn't need
  `TruexRendererFactory`.
- It shares the root [Version.xcconfig](../Version.xcconfig) with the Swift app.
