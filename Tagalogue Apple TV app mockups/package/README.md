# Tagalogue TV — Apple TV brand package

## What is here

    Assets.xcassets/
      Brand Assets.brandassets/
        App Icon.imagestack/            400 × 240 @1x, 800 × 480 @2x — Front / Middle / Back
        App Icon - App Store.imagestack/ 1280 × 768 — Front / Middle / Back
        Top Shelf Image.imageset/        1920 × 720
        Top Shelf Image Wide.imageset/   2320 × 720
    Launch/
      launch-1920x1080.png
    Logos/
      logo.svg  logo-dark.svg  logo-mono.svg      full lockup
      mark.svg  mark-dark.svg  mark-mono.svg      heart only, for use under ~250 px

## Installing

1. Drag `Assets.xcassets` into the Xcode project (or drag `Brand Assets.brandassets` into an existing catalog).
2. Target → Build Settings → **Asset Catalog App Icon Set Name** → `Brand Assets`.
3. The launch image is a plain PNG; set it in the launch storyboard or as the launch image asset.

Layer order in each stack is Front, Middle, Back — top to bottom. Back is the opaque ink plate, Middle carries the heart, Front carries TL / TV and the microphone. Corners are square on purpose: tvOS applies its own mask and the focus highlight.

## Colour

    ink        #0b0a0a     ground, back layer
    accent     #ec3013     focus, primary action, badges
    paper      #f3f2f2     text on ink
    heart      from the artwork — do not recolour

## Still needed before submission

- **Real stills.** Every image in the UI mockups is a placeholder.
- **App Store screenshots.** 1920 × 1080, three to ten of them, captured from the running app.
- **Top shelf content.** The static images here are the fallback. A shipping app usually serves a dynamic top shelf (sectioned or inset banner) through a TVTopShelf extension.
- **App name and subtitle** as they should read on the App Store, plus the age rating and category.
- **Localisation.** The interface is English only. Tagalog and German are the obvious second and third.
- **Video pipeline.** HLS streams, subtitle tracks (EN, TL), and artwork per episode.
