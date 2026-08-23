# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

Two halves that depend on each other:

- **`Tagalogue Apple TV app mockups/`** — the design package (not code). Exported from a design tool; holds the brand assets and, critically, **`Apple TV App.dc.html`** — a five-screen tvOS UI spec at 1920×1080 with exact type, spacing and colour values. **This file is the design source of truth.** Open it in a browser when building or changing any screen.
- **`tagalogue.tv/`** — the Xcode project (`tagalogue.tv.xcodeproj`), a tvOS SwiftUI + SwiftData app. This is the only part that builds.

Note the design package is re-exported wholesale from the design tool from time to time, which **replaces the whole folder** — never hand-edit anything inside it and expect the change to survive. Its layout has changed before (assets used to sit at the top level; they now live under `package/`, `assets/` and `exports/`).

Tagalogue TV is a Filipino–Swiss channel (Taxed GmbH, Biel/Bienne). Content is Tagalog/English; the interface is English only.

## Build and run

```bash
cd tagalogue.tv
xcodebuild -project tagalogue.tv.xcodeproj -scheme "tagalogue.tv" \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' build
```

The tvOS platform is a separate, multi-gigabyte download from Xcode itself — `xcodebuild -downloadPlatform tvOS`. Without it, even `-destination generic/platform=tvOS` fails with "tvOS is not installed", so a fresh machine cannot build this until that completes.

There are no tests.

## Architecture

`ContentView` is the shell: a custom `NavBar` over a section switch (`AppSection` — Home / Interviews / Vlogs / My List / Community / Search, plus a Debug-only Send), with a `NavigationStack` whose `Route` cases push detail and player. The enum is `AppSection` rather than `Section` deliberately — SwiftUI already exports a `Section` view, and shadowing it is a trap.

Content is static: `Resources/catalog.json` decodes into `Catalog → Show → Episode → Chapter` via `CatalogStore` (ISO-8601 dates). Shows are the channel's strands (Interviews, Vlogs); vlogs use `number: 0` to mean "unnumbered", which is what suppresses the `EP n` part of the meta line — always go through `metaLine` / `cardMeta` / `detailMeta` rather than interpolating `number` by hand, which is how "EPISODE 0" reached all six vlog detail pages. `publishedAt` drives Latest, the hero and the Top Shelf.

SwiftData persists only viewing state — `WatchProgress` (resume positions, drives Continue Watching) and `ListEntry` (My List — see below). The catalog itself is not in SwiftData.

**Never read `WatchProgress` directly.** Go through `Episode.resume(from:)`, which returns a `Resume` reconciled against the catalog's duration. The stream's own duration is trusted only when it agrees to within 5%: a placeholder stream, a re-encode or a mid-roll of the wrong length would otherwise push `fraction` past the completion threshold and silently retire an episode from Continue Watching. `Resume` also owns the resume floor (30s) and the end guard (10s) that keeps a stale marker from dropping the viewer on the credits.

Playback uses `AVPlayerViewController` via `UIViewControllerRepresentable`, not SwiftUI's `VideoPlayer`, because on tvOS it is what supplies the transport bar, scrubbing, chapter navigation and subtitle menus. **Its chrome is system-drawn and cannot be restyled**, so the Archivo-and-red transport drawn in screen 04 of the design doc is not reachable without hand-building transport, scrubbing and media selection over a raw `AVPlayer`. Chapters reach the native strip through `AVNavigationMarkersGroup`. Search does **not** use the system `.searchable`. That was tried and abandoned: on tvOS 26 it presents a single-row horizontal keyboard strip across the top with results in one full-width column below — system-styled rounded pills, localised to the device, stacked under the app's own nav bar as a second header. That is not screen 05. `SearchKeyboard.swift` draws the design's 660pt grid keyboard instead, and `SearchView` puts results in the right column.

`ContentView` also handles `tagaloguetv://` deep links (`Shared/DeepLink.swift`) from the Top Shelf extension.

### My List, playlists and Up Next

My List is the app's own feature: `ListEntry` in SwiftData, a `My List` nav section (`MyListView`) plus a Home rail. It is deliberately **not** built on any Apple playlist API, because neither candidate fits:

- **`TVMLKit.TVPlaylist`** is a read-only *playback queue* belonging to the TVML JavaScript player, not a user watchlist — and it is **deprecated as of tvOS 18** ("use SwiftUI or UIKit"). TVMLKit has no place in this app.
- **Up Next in the Apple TV app is not writable by third-party apps.** Apple's integration needs, in order: a **catalog feed** submitted to Apple that assigns each episode a stable `contentId`; the **universal search extended entitlement** on the provisioning profile, granted as part of that onboarding; playback reported through the **Now Playing API** carrying that same contentId with duration and elapsed time; and an **`NSUserActivity`** on the detail screen carrying it too, so "Hey Siri, add this to my Up Next" has something to add.

The last two are implemented in `Services/UpNext.swift` and already earn their keep — Now Playing drives the Siri Remote info panel, and the activity makes episodes handoff- and Siri-addressable. The first two are business steps for Taxed GmbH. **When the feed exists, `UpNext.contentID(for:)` must return the feed's id, not the catalog's** — the two halves have to match or nothing lines up.

### Send from your phone — Debug-only ingest

`Send` is an internal content-preview tool: the TV shows a QR code, a phone scans it, picks a
video, and it plays in the real chrome without a rebuild. Precedent is VLC for Apple TV, which
serves an upload page the same way.

**It is compiled out of Release.** `Services/Ingest/*`, `DesignSystem/QRCode.swift` and
`Views/SendView.swift` are all wrapped in `#if TAGALOGUE_INGEST` (set in
`SWIFT_ACTIVE_COMPILATION_CONDITIONS` for Debug only), so a shipping binary carries no HTTP
server and never accepts uploaded video — which keeps App Review's user-generated-content rules
(guideline 1.2) out of scope. Verify with
`strings …/Release-appletvsimulator/tagalogue.tv.app/tagalogue.tv | grep -c LocalHTTPIngestSession`
— it must be 0. The two local-network keys in `Info.plist` do ship and are simply unused there;
splitting the plist per configuration would duplicate the font list and invite exactly the kind
of drift this file keeps warning about.

How it fits together:

- `IngestSession` is the seam. `LocalHTTPIngestSession` is the LAN implementation; a Cloudflare
  Stream implementation would replace it without touching `SendView`. Everything the screen
  needs is in `IngestEvent` (`waiting` / `receiving` / `ready` / `failed`).
- **No multipart.** The served page PUTs the raw file as the request body via `XMLHttpRequest`,
  so the server parses a request line, a `Content-Length` and a byte count. `fetch` has no
  upload-progress event, which is why it is XHR.
- **Uploads live in `Library/Caches/Uploads`, never in `tmp`.** This was got wrong once and the
  symptom is worth remembering: tvOS clears `tmp` whenever the app is not running, so an uploaded
  clip and its poster were both gone by the time anyone pressed play — the card lost its thumbnail
  and playback failed with a bare CoreMedia error. Caches is where tvOS puts this app's own
  SwiftData store (it redirects Application Support there), so an upload now lasts as long as
  Continue Watching does. It is still purgeable under storage pressure, so `restore()` drops any
  sidecar whose video has vanished rather than showing a card that cannot play.
- **Sidecars store the `Episode` itself** (it is already `Codable`) next to the video, and
  `relocated(into:)` rewrites the paths on load — container paths change on every reinstall, so
  absolute paths written last time are stale.
- Uploads live in `CatalogStore.uploads`, deliberately **not** merged into `catalog`: they are
  not part of the channel and nothing should be tempted to write them back to `catalog.json`.
  Use `store.anyEpisode(id:)` when a lookup must find both.
- `Episode.playbackURL` and `BundledArtwork.image(named:)` treat a leading `/` as an absolute
  path, which is how a received file and its generated poster are addressed.
- `Services/MediaProbe.swift` is the single copy of the `AVAssetImageGenerator` dance; the
  player's ambient backdrop and ingest's poster frame both go through it.

**Authoring happens on the phone, not the television.** The served page is a form — title,
description, strand, optional thumbnail — because the phone is the only device in the room with a
keyboard. The TV then offers four candidate frames so the poster can be changed without
re-uploading; without a chosen thumbnail the poster is taken from **ten seconds in**
(`IngestedEpisode.defaultPosterSeconds`), which skips the black frame most clips open on.

**Publishing** is `CloudflarePublisher`: it uploads the local file to Stream, polls until the
encode is `ready`, and rewrites the episode to point at
`https://customer-<CODE>.cloudflarestream.com/<UID>/manifest/video.m3u8`. Credentials come from
`Resources/CloudflareConfig.plist` — gitignored; copy `CloudflareConfig.example.plist`. The token
needs `Stream:Edit` only.

That token is acceptable **only** because this whole feature is compiled out of Release. A build
that reaches users must never carry it: the public path is Direct Creator Uploads behind a Worker
(`POST /session` → `{sessionID, pageURL}`; `POST /session/:id/upload-url` → a one-time URL;
`GET /session/:id` → `{state, uid}`), with the phone uploading straight to Cloudflare — basic POST
under 200 MB, tus above.

**Two things publishing does not yet do.** Stream generates its own thumbnails from the video and
has no API for uploading a custom image, so a chosen thumbnail stays local and would need its own
hosting (R2) to reach viewers. And a published clip is still only visible on the device that
published it, because `catalog.json` is bundled: for other people to see it, the catalog has to
become something the app fetches.

One trap worth remembering: `SendView`'s nested state enum is called `Phase`, not `State` — a
nested `State` shadows SwiftUI's `@State` attribute and every property wrapper in the file stops
compiling. Same family of mistake as `AppSection` vs `Section`.

### Aspect ratio — a constraint the removed preview assets exposed

The sample poster and clip that once shipped in `Resources/` are gone, along with the
fifteen invented episodes that referenced them. What they taught is worth keeping.

**Both were portrait: a 3:4 poster with its own baked-in headline, and a 9:16 video.** This interface is 16:9 with its own typography, so:

- Cards centre-crop (`ArtStyle.thumbnail`), which loses most of a portrait poster.
- The hero and the detail still use `ArtStyle.showcase` instead: the artwork held whole to one side over a blurred, darkened copy of itself, leaving a clean area for the app's title and meta. Without it the poster's own "BELOVED FORMER SWISS PRESIDENT" panel landed straight on top of the detail screen's meta line.
- The player draws an **ambient backdrop** — a frame of the video, blurred with Core Image — behind a pillarboxed picture, so a 9:16 clip is not two black voids. Plus a **channel bug** top-right.

**Real stills should be 16:9 and carry no text**; the app draws the title. Real video should be landscape. The showcase and ambient treatments then still work, they just stop being load-bearing.

Two notes for anyone touching `PlayerView`: `videoGravity` must be re-asserted in `updateUIViewController` — setting it once before the view loads does not stick, and a 9:16 clip was being cropped to fill. And the ambient backdrop and channel bug live *inside* AVKit's hierarchy (`view.insertSubview(_:at: 0)` and `contentOverlayView`), because on tvOS the player takes over the screen and anything stacked around it in SwiftUI never appears.

Real content comes from Cloudflare Stream, published through `tools/cms`. The videos also live on the channel's YouTube account, but **YouTube cannot be a runtime source**: tvOS has no web view, there is no YouTube tvOS SDK, and extracting stream URLs breaks YouTube's ToS and App Review guideline 5.2.1. Exporting your own masters once and re-hosting is the supported path.

## The catalog is remote

`catalog.json` in the bundle is now only a **seed**, and it holds **no episodes** — just the
three strands (`interviews`, `vlogs`, `community`) with empty arrays, matching `STRANDS` and
`COMMUNITY_STRAND` in the content tool. It exists so a fresh install has a correctly-shaped,
decodable catalog before its first fetch, and so the Top Shelf extension always finds a file.
**Never put an episode in it**: anything here appears on a television as though it were real
programming, which is how fifteen invented episodes were briefly the live channel.

Because the channel can legitimately be empty, Home and the category grids have empty states
(`HomeView.emptyState`, `CategoryGridView.emptyState`) and no rail draws a heading over zero
cards. Before that, an empty catalog rendered as four bare rail titles on black with nothing
focusable, which reads as a crash rather than as a channel awaiting its first episode.
 `CatalogStore` reads three layers, in order of
trust: the copy fetched this launch, the copy cached in `Library/Caches` from last time, and the
bundled one. A viewer should never see an empty screen because the network was slow, and a fetch
that returns zero shows is refused rather than blanking the channel.

Set `TagalogueCatalogURL` in `Info.plist` to point at a catalog. Absent, the app runs on the bundle
alone, exactly as it did before. `TagalogueCatalogFallbackURL` is tried only when the first fails —
one hostname is one point of failure, and not a theoretical one: while the domain's old nameservers
were still cached, `cdn.tagalogue.tv` did not exist as far as some resolvers were concerned, and a
television on one of those could not reach the channel at all. The fallback is the bucket's own
address, which does not depend on that record.

**Publishing an episode never needs an app build.** The catalog is fetched at runtime, so the only
question is *when* the television looks. It looks on launch (`.task` on `ContentView`) and again
whenever the app returns to the foreground (`scenePhase == .active`). The second one matters more
than it sounds: tvOS suspends an app rather than terminating it, so reopening the channel is usually
a resume, the view never reappears, and without that observer an episode published in the meantime
stays invisible until something forces a cold launch — which reads to everyone as "the app has to be
updated to get new videos".

Episodes published this way carry `artworkResource` as an **`http(s)` URL** rather than a file path;
`EpisodeArt` handles all three shapes (remote URL, absolute file path, bundled name).

## Community submissions

The QR code on the **Community** section is for followers, not for the team. It leads to the
channel's own submission page (`TagalogueSubmitURL` → `tools/cms` `/submit`), **not** to the Apple
TV in the viewer's living room — a follower's video has to reach Taxed GmbH, not sit on their own
device. That is why this section ships, needs no local-network permission and runs no server.

The path is deliberately one-way: a submission lands in `tools/cms/.data/submissions.json` as
`pending`, and the only way out is an editor opening it in the same editor everything else uses —
title, thumbnail, trim, strand, schedule — and pressing **Approve and publish**. Approved videos
become episodes in the `community` strand. **Nothing a stranger sends can reach a television by
itself**, which is both the editorial position and the only defensible one.

**Before this goes to App Review**: the app now solicits user-generated content, so guideline 1.2
applies. Moderation is covered (nothing publishes unreviewed) and the submit page carries a consent
line, but Apple will also expect published terms and a way for viewers to report content. Neither
exists yet.

## tools/cms — the content tool

A Next.js app, in `tools/cms`, that is where episodes actually come from: upload a video, give it a
title, a description, a strand and a thumbnail, press publish. It writes the catalog the television
reads. **The television is not a CMS** — that was tried (see the Debug-only `Send` section) and it
is the wrong place for typing.

`npm run dev` on port 4000. It defaults to `STORAGE=local`, which writes to `tools/cms/.data` and
serves it back, so the whole loop — including the Apple TV reading and playing from it — works
before any Cloudflare account exists. `tools/cms/README.md` has the cloud switch.

**One Worker, three audiences, live at `tagalogue.tv`.** `/` is the public site (what the channel is, how to watch,
a link to submit). `/admin` is the editor — everything that publishes, edits or reviews.
`/submit` is the community form. `lib/auth.ts` is **deny-by-default**: `isPublicPath` lists
what is open and nothing else is, so adding a public page can never widen the hole around the
tool. The editor lives at `/admin` rather than `/` for exactly that reason.

Deny-by-default catches more than pages: `app/icon.png`, `app/apple-icon.png` and
`app/opengraph-image.png` are Next file-convention **routes**, not `/public` files, so they
need naming in `isPublicPath` — without it every link preview fetches the sign-in page.

**The public site splits the ground; the television does not.** `/`, the policy pages and
`/submit` run the same Modernist system the right way up: an ink masthead, hero and footer
carrying the brand, everything read at length on paper (`#f3f2f2`, text `#201e1d`), and one
full field of red for the closing banner — the one place the design system's own readme
allows the accent to run as a field. A whole site of type on `#0b0a0a` read as a void,
especially with nothing published. The light tokens are lifted from
`_ds/modernist-<id>/styles.css`, not invented. `/admin` and `/login` stay on ink.

Structurally, `.site` is a full-width flow and each section is a `.band` owning its ground
full-bleed with a `.band-inner` holding the measure — so **do not put a `max-width` back on
`.site`**, which is what made a split ground impossible before. Chrome is shared:
`app/_components/SiteHeader.tsx` and `SiteFooter.tsx`. Note `#ec3013` measures 3.83:1 on
paper — fine for display type, rules and button fills, not for body copy or small links,
which use `--accent-deep` (`#ae1800`, 6.5:1).

`globals.css` is one flat namespace shared with the editor, and the public rules used to be
written last: `.panel` and `.steps` were each defined twice and silently restyled `/admin`.
The public ones are now `.site-panel` and `.site-steps`. **Prefix anything new.**

**Secrets need a deploy.** `wrangler secret put` stores the value immediately and
`wrangler secret list` confirms it, but the running Worker keeps reading the previous one
until `npm run deploy`. This wasted an afternoon once: a correct Stream token returned
`10000 Authentication error` from the Worker while the identical token worked from a
laptop, which looks exactly like an IP restriction or a missing permission and is neither.

An episode carries more than it used to: `visibility` (public / unlisted / draft), `tags`,
`maturity`, `seriesID`/`seriesTitle`, `captions`, and `trimStart`/`trimEnd`. All optional, so an
older catalog still decodes.

**A malformed episode must not blank the channel.** `Shared/Catalog.swift` declares
`subtitles` and `chapters` non-optional, and synthesized decoding is all-or-nothing: one
episode missing either used to throw, which failed `Catalog.decode`, which made
`RemoteCatalog.fetch` return nil, which silently left every install on its last cached copy.
Nothing appeared broken on screen — the channel simply stopped updating. `Show` and `Catalog`
now decode their arrays through `Lossy<T>`, whose own decoding never throws, so an unreadable
episode costs that episode and nothing else. `POST /api/catalog` also validates and fills the
two arrays, so the safety net should never be needed.

**Top 10 today is counted on the server, never on the television.** `/privacy`
promises no analytics, and the app keeps that promise: watch progress lives in
SwiftData on the Apple TV and is never sent anywhere, so the app cannot know
what is popular. Cloudflare already counts playback at the edge as an aggregate
with no viewer in it, and `lib/analytics.ts` reads those totals — minutes viewed
per video, not play count, because a play is registered the moment somebody
lands on a video and that would just rank whatever sits in the hero.
`POST /api/top` ranks them, maps `uid` → `cf-<uid>`, and writes `topToday` into
the catalog; the app resolves it through `allEpisodes` so an unpublished or
expired episode drops out of the chart too.

Two things about it: the Stream token needs **Account Analytics:Read** on top of
`Stream:Edit`, and secrets need a redeploy to take effect. And when the numbers
cannot be read the chart is left **exactly as it was** rather than emptied —
an empty "Top 10 today" claims nobody watched anything, which is a different
and false statement. It recomputes after each publish and from the button in
`/admin`; a scheduler pointed at `/api/top` is what would make it truly daily.

**The television enforces three of these itself, and that is deliberate** — the app must be correct
even if it is pointed at an unfiltered feed:

- `Catalog.allEpisodes` — what belongs in a rail: released, published, listed.
- `Catalog.playableEpisodes` — adds unlisted, so a deep link reaches one. That is what "unlisted" is.
- `Catalog.everyEpisode` — includes drafts and scheduled. Tooling only.

Scheduling therefore needs no cron anywhere: an episode dated in the future is filtered out until
its moment. Trimming is non-destructive — `PlayerView` seeks to `startOffset`, reports progress
relative to it, and treats reaching `endOffset` as the end of the episode.

Two things to know before changing it:

- **`lib/catalog.ts` mirrors `Shared/Catalog.swift` field for field.** Rename a field there and the
  channel stops showing it.
- The local media route implements **HTTP range requests**. Without them AVPlayer opens the file,
  gets a 200 where it asked for a 206, and dies with "Operation Stopped".

## Design system — Modernist, inverted onto ink

Everything is set in **Archivo**, which is **not a tvOS system font**. It is bundled as six static instances in `Resources/Fonts/`, generated by instancing Google's variable `Archivo[wdth,wght].ttf` at weights 400–900. Their PostScript names are `ArchivoRoman-Regular`, `-Medium`, `-SemiBold`, `-Bold`, `-ExtraBold`, `-Black` — note the `Roman`, which is easy to get wrong. Registration is via `UIAppFonts` in a partial `Info.plist` at the project root, merged with the generated one (`GENERATE_INFOPLIST_FILE` stays `YES` alongside `INFOPLIST_FILE`). If it breaks, the whole UI silently falls back to the system sans; a `DEBUG` check in `tagalogue_tvApp.swift` logs whether Archivo registered.

Tokens live in `DesignSystem/Theme.swift`. The palette is confirmed against pixels, not just docs — the accent rule along the bottom of `TopShelfWide.png` samples as a uniform `#ec3013` on a uniform `#0b0a0a` ground:

| Token | Hex |
|---|---|
| ink (ground) | `#0b0a0a` |
| paper (text) | `#f3f2f2` |
| accent | `#ec3013` |

Four rules the design doc states outright, all enforced in `DesignSystem/FocusStyle.swift`:

- **Focus** — 4pt accent border and a 4% lift. *Never a glow, never a rounded corner.* tvOS's stock focus effect is exactly the rounded, glowing lift this forbids, so every focusable surface opts out and draws its own rectangle.
- **Safe area** — 90pt left/right, 60pt top/bottom, applied **once**. tvOS inserts its own insets (~89/60), so `.ignoresSafeArea()` has to sit on the content *inside* the `NavigationStack`, never on the stack itself: on the stack it only lets the background bleed while the stack still hands its root the full insets, and they stack with the 90/60 padding. That bug put every screen ~89pt right and 120pt low and clipped the full-bleed hero 80pt short of the frame. Check it by sampling a screenshot: the Home NEW badge's left edge must land at x=90.
- **Type floor** — the design doc says 19, written for a browser. The interface uses **23pt**, tvOS's Caption 2, which is `Theme.Metrics.typeFloor` and what every screen actually follows. Sizes were raised to clear it; letter-spacing must be raised with them, which is why `archivo(_:_:tracking:)` sets face, size and tracking in one call — applying `.font` and `.tracking` separately is how the interface once drifted 16–24% tight.
- **Accent** — red marks focus, the primary action and the NEW badge. **Nothing else.**

tvOS renders at 1920×1080 points, so every px in the design doc maps 1:1 to a SwiftUI point. No conversion.

Focus borders belong on the artwork rectangle only, never wrapping the caption — which is why cards make the art the `Button` and place the caption outside it, tracking focus with `@FocusState` to tint the text.

### Top Shelf

`TopShelf/` is a `TVTopShelfContentProvider` app extension showing the latest episodes on the tvOS home screen. It ships **code only**: `catalog.json` lives in the containing app (`Bundle.containingApp` walks up to the enclosing `.app`), and the models come from `Shared/`, a synchronized group compiled into *both* targets so the shelf can never describe an episode differently from the app. Items deep-link back in via `tagaloguetv://`.

It cannot show Continue Watching: that lives in SwiftData inside the app container, and reading it from the extension would need an **App Group**, which means a portal-registered group id and an entitlement change on both targets.

## Assets

The catalog is `tagalogue.tv/tagalogue.tv/Assets.xcassets`, using the Xcode template's `App Icon & Top Shelf Image.brandassets` name (matched by `ASSETCATALOG_COMPILER_APPICON_NAME`). Source images come from `Tagalogue Apple TV app mockups/exports/`.

- Every directory's `Contents.json` declares its children **by exact filename**. Rename or add an image without editing the parent in the same change and Xcode silently drops the asset.
- App icons are **layered image stacks** (parallax), not flat images: Front / Middle / Back, top to bottom. Back is the opaque ink plate, Middle carries the heart, Front the TL/TV wordmark and microphone. They must stay separate files with transparency — flattening destroys the effect tvOS is built around.
- Sizes are fixed by role: App Icon 400×240 @1x / 800×480 @2x; App Icon - App Store 1280×768 (1x only, no @2x); Top Shelf 1920×720; Top Shelf Wide 2320×720.
- Icon corners are square deliberately — tvOS applies its own mask and focus highlight.

The logos (`assets/*.svg` in the design package, byte-identical to `package/Logos/`) are **auto-traced raster art**: ~1020 paths and up to ~1000 distinct fills each, ~360 KB per file, not hand-editable. `mark-*` is only a tighter `viewBox` crop of `logo-*`; `-dark` drops 177 light paths to `fill="none"` and flips 75 wordmark paths to `#fafafa`; `-mono` is that, desaturated. The trace contains the **Philippine and Swiss flag colours**, which is why the brand note *"heart — do not recolour"* matters: hue-shifting the reds would wreck the flags. Any real logo change means going back to the original artwork.

Do not try to derive the brand accent from the SVGs — the artwork holds 354 distinct saturated reds and its largest by area (≈`#f00f05`) is incidental. `#ec3013` is the spec, and it is what the shipped assets actually use.
