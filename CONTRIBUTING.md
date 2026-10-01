# Contributing

## Prerequisites

- Xcode 16 or newer
- An iOS Simulator runtime (or a device) running iOS 15.6 or newer
- Network access to the sample media, Google IMA, and the TrueX renderer Swift package

## Build and test

Build the Swift app:

```shell
xcodebuild build \
  -project swift-ios-app/InfillionAdsExamples.xcodeproj \
  -scheme InfillionAdsExamples \
  -destination 'generic/platform=iOS Simulator'
```

Run all unit tests (use any available iPhone simulator):

```shell
xcodebuild test \
  -project swift-ios-app/InfillionAdsExamples.xcodeproj \
  -scheme InfillionAdsExamples \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Branch workflow

While this repository has no remote and is being bootstrapped locally, direct work on `main` is allowed.

After the initial remote push:

1. Fast-forward local `main` to `origin/main`.
2. Create `feature/<TICKET>/<description>` for a feature or `bugfix/<TICKET>/<description>` for a bug.
3. Implement the change and ensure all code-related changes pass the unit tests.
4. Increment the app version.
5. Commit and open a pull request into `main`.
6. Wait for the approvals required by company policy.
7. Merge the approved pull request manually through the GitHub web interface.

Do not commit directly to remote `main`.

## Versioning

[Version.xcconfig](Version.xcconfig) is the version source of truth for every app in this repository:

```text
VERSION_CODE = 1
VERSION_NAME = 1.0.0
```

The Xcode projects map them to the build settings: `CURRENT_PROJECT_VERSION = $(VERSION_CODE)` and
`MARKETING_VERSION = $(VERSION_NAME)`. Don't set either build setting anywhere else.

Every pull request must:

- Increment `VERSION_CODE` by exactly one.
- Increment the patch component of `VERSION_NAME` by exactly one (for example, `1.2.3` → `1.2.4`).
- Leave the major and minor components unchanged.

The pull-request workflow compares both values with the target `main` revision and fails if either increment is incorrect.

## Commits

Commit messages and pull request titles use `<TICKET> - <MESSAGE>`, for example:

```text
PI-3533 - Add Swift iOS examples app
```

Pull request titles must be shorter than 80 characters.

## Pull requests and releases

Use [.github/pull_request_template.md](.github/pull_request_template.md) for the pull request description. Every pull request must pass all unit tests and validate the version increment.

After an approved pull request is manually merged to `main`, the release workflow creates tag `v<VERSION_NAME>` and a GitHub release with generated release notes.
