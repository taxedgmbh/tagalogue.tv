# Tagalogue TV · Content

The tool that puts episodes on the channel. Upload a video, give it a title, a
description and a thumbnail, and press publish — every Apple TV picks it up.

Built as a Next.js app so the television does not have to be a content
management system. The tvOS app only *reads* the catalog this tool writes.

---

## Run it locally

```bash
cd tools/cms
npm install
npm run dev            # http://localhost:4000
```

That is the whole setup. **Local mode needs no Cloudflare account**: videos,
thumbnails and the catalog are written to `tools/cms/.data` and served straight
back out, so the entire flow can be used and tested before anything exists in
the cloud.

### Pointing the television at it

The Apple TV reads whatever `TagalogueCatalogURL` in the app's `Info.plist`
says. For local testing set it to your Mac's LAN address — **not** `localhost`,
which means the television itself:

```xml
<key>TagalogueCatalogURL</key>
<string>http://192.168.0.14:4000/api/catalog</string>
```

Plain HTTP also needs an ATS exception in the app for local testing. Both come
out again when you move to the cloud, where everything is HTTPS.

Find your address with `ipconfig getifaddr en0` (or `en1` on some Macs), and
set the same value as `PUBLIC_BASE_URL` in `.env.local` so the URLs written
into the catalog are ones the television can reach.

---

## Move it to Cloudflare

Set these in `.env.local` (or as environment variables wherever you host it):

```
STORAGE=cloudflare
PUBLIC_BASE_URL=https://content.tagalogue.tv
CF_ACCOUNT_ID=…
CF_API_TOKEN=…             # Stream:Edit
CF_CUSTOMER_CODE=…         # the customer-<CODE> subdomain on the Stream page
R2_BUCKET=…
R2_PUBLIC_BASE_URL=https://pub-<hash>.r2.dev
R2_ACCESS_KEY_ID=…
R2_SECRET_ACCESS_KEY=…
```

Then in the tvOS app set `TagalogueCatalogURL` to
`https://pub-<hash>.r2.dev/catalog.json` — the catalog is served straight from
the bucket, so viewers never touch this tool and it can go offline without
taking the channel with it.

What changes in cloud mode:

- The browser uploads **straight to Cloudflare Stream** using a Direct Creator
  Upload URL. Video bytes never pass through this server, so it can run
  anywhere small.
- The catalog is written to R2. Reads are public; writes are signed S3-style,
  because R2's object API does not take bearer tokens.
- Thumbnails: a frame you picked is served by Stream itself at that exact
  timestamp and costs no storage. An image you upload goes to R2.

**Nothing here belongs in the tvOS app.** The API token can write to your whole
Stream account; it lives on this server only.

---

## What an episode carries

| Field | What it does |
|---|---|
| **Visibility** | `public` listed everywhere · `unlisted` playable by direct link but never listed · `draft` never leaves this tool |
| **Release** | A time in the future means scheduled. **Nothing runs on a timer** — the television hides an episode until its moment, so a catalog is published once and simply becomes visible. |
| **Trim** | In and out points. Non-destructive: the file is never re-encoded, the television just starts and stops there, so a cut can be adjusted or undone. |
| **Tags** | Searched on the television alongside the title, description and chapter names. |
| **Collection** | Groups episodes across strands. |
| **Audience** | General / Teen / 18+. Metadata for a parental control to read; nothing is enforced yet. |
| **Captions** | WebVTT per language. On Cloudflare these join the stream itself, so the television's own subtitle menu picks them up. |

**Unpublish** drops an episode back to draft without destroying anything. **Delete** asks first,
then removes it from the catalog for good.

### Deliberately not built

Three things worth naming, because a switch that does nothing is worse than no switch:

- **Monetization.** There is no ad server, no payment path and no entitlement check anywhere in
  this project. A toggle would promise something the app cannot do.
- **End screens and cards.** The detail screen already ends with a "More from …" rail. A real end
  screen needs player work on the tvOS side, not a field here.
- **Audio normalization and multi-track audio.** Cloudflare Stream does not normalise loudness, and
  multi-track audio has to exist in the master before upload. Neither is something this tool can
  honestly offer.

A separate **Category** field was also left out on purpose: the channel's strands
(Interviews / Vlogs) already are the category, and a second taxonomy over the same content would
just drift out of step with the first.

## Community submissions

`/submit` is public — it is what the QR code on the television leads to. A follower gives a name,
a message and a video, and it lands in the review queue. **Nothing published, nothing listed, no
account.**

The editor sees waiting submissions above the catalog. **Review** opens one in the same form as
everything else, so a phone video from a stranger gets the same title, thumbnail, trim and
scheduling tools a finished episode does — it needs them more, not less. **Approve and publish**
turns it into an episode in the `community` strand; **Decline** closes it without a trace on the
channel.

Two limits are built in, because an unauthenticated upload endpoint is a standing invitation:
500 MB per video, and a submission can only leave `pending` by hand.

## How it works

```
browser ──1─→ /api/upload-url ──→ Stream direct upload (or .data in local mode)
   │
   ├──2─→ uploads the file straight to that URL, with progress
   ├──3─→ polls /api/video/<uid> until Cloudflare says "ready"
   ├──4─→ posts the chosen thumbnail to /api/thumbnail
   └──5─→ posts the finished episode to /api/catalog
                                      │
                        catalog.json ─┴─→ every Apple TV
```

The four thumbnail candidates are drawn **in the browser** — the file is loaded
into a `<video>`, seeked, and painted onto a `<canvas>`. Nothing is uploaded
until you press publish, so choosing a frame costs nothing and you can discard
a clip without ever sending it.

`lib/catalog.ts` mirrors `Shared/Catalog.swift` in the tvOS app field for
field. **A field renamed here is a field the channel stops showing.**

## Routes

| | |
|---|---|
| `GET /api/catalog` | What the television reads. |
| `POST /api/catalog` | Add or replace an episode. |
| `DELETE /api/catalog?id=` | Remove one. |
| `POST /api/upload-url` | Where to send the video. |
| `GET /api/video/[uid]` | Encoding status and the playback URL. |
| `POST /api/thumbnail?uid=` | Store a thumbnail. |
| `GET /api/media/[...path]` | Local mode only — serves `.data`, with HTTP range support so AVPlayer can scrub. |
