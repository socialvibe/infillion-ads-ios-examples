# Design

The iOS app follows the Android examples' `DESIGN.md`, adapted from a ten-foot TV launcher to a touch phone and
tablet UI.

## Color

- `Charcoal #2D2D2D`: launcher and navigation bar background.
- `Deep Charcoal #242222`: example cards and the player status surface.
- `Fog Gray #F6F6F6`: primary text and the logo.
- `Muted Fog #E4E4E4`: explanatory text.
- `Bloom #BB6AEF -> #F948A1 -> #FC5D3D`: card accent bar; `#F948A1` is the tint color.

The app is dark only. Player screens stay black with one compact status surface, so the ad and playback state
remain primary.

## Typography

Be Vietnam Pro is bundled in Regular, Medium, and Bold and scales with Dynamic Type. Titles are bold, explanations
regular, and compact labels (chips, status, navigation title) medium.

## Launcher

The official light Infillion wordmark sits in the navigation bar. A heading and one sentence introduce the app,
followed by one card per example: title, one-line description, and delivery / insertion chips. Cards use a 20-pt
continuous corner radius, a low-contrast neutral stroke, and a 4-pt Bloom bar on top; pressing scales a card to
0.98. The content is capped at 640 pt wide on iPad.

## Player screens

Each example uses a native `AVPlayerViewController`, the renderer above it, and the status surface in the
upper-left safe area. While the renderer is active the navigation bar, status bar, and home indicator are hidden.
Status copy identifies content, ad request, linear ad, interactive ad, recovery, or error.

## App icon

The Infillion mark in Fog Gray on Charcoal.
