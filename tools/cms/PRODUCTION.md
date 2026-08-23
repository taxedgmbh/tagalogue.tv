# Going to production

Where the launch actually stands. Everything marked ✅ was verified by running it,
not by reading the code. Items marked **blocker** stop the launch.

## Live now

| | |
|---|---|
| **The tool is deployed** | `https://tagalogue-content.tight-unit-b07f.workers.dev` — R2 bound, secrets set, preview URLs off. ✅ |
| **Auth holds in production** | Public reads 200, editor redirects to login, every write 401, a forged cookie 401, and the real password signs in. ✅ |
| **R2 bucket** | `tagalogue-media`, public reads at `https://pub-59f39c9e91c34695acada7303f42a801.r2.dev`, CORS `GET`/`HEAD`, writes only through the Worker's binding. ✅ |
| **The catalog** | Served publicly with `Cache-Control: public, max-age=60`. ✅ |
| **The televisions read it** | Proven by changing a title *only in R2* and watching it appear on the simulator — the app cannot have got that from its bundle. ✅ |
| **Stream is enabled** | Verified by creating and deleting a real upload slot. The account has no videos on it. ✅ |
| **The editor password** | Generated, set as a secret, and stored in the login Keychain: `security find-generic-password -s tagalogue-cms -a info@taxed.ch -w` |

## The channel is on air

The whole path is proven end to end: signed in on the deployed Worker, requested a
Direct Creator Upload URL, pushed a 16 MB video straight to Stream, watched it encode,
and got back a playable HLS manifest, a thumbnail and a duration. The test video has
been deleted again, so Stream is empty.

### Verified: scheduled release, against live infrastructure

Published an episode dated three minutes out through the deployed tool. Before its moment the
television had it in the fetched feed — confirmed in the app's own cache on disk — and did not
show it. At its moment, without a redeploy or anything on a timer, it became the hero and the
first card in Latest. Then deleted again.

That test also found a real fault, now fixed: an episode missing `subtitles` or `chapters` made
the whole catalog undecodable, so every television silently fell back to its bundled copy with
nothing visibly wrong. The app now drops an unreadable episode instead of the whole feed, and
the publish endpoint refuses or repairs one before it is written. See CLAUDE.md.

### One trap, which cost most of the debugging

**`wrangler secret put` does not reach the running Worker until the next deploy.** The
secret is stored immediately and `wrangler secret list` shows it, so everything looks
correct — but the code keeps reading the previous value. The symptom is a stale
credential producing `10000 Authentication error` from the Worker while the *same*
token works perfectly from a laptop, which reads like a permissions or IP problem and
is neither.

After changing a secret, always:

```
npm run deploy
```

The same applies to rotating `CMS_PASSWORD`.

## The public site

`tagalogue.tv` is live: landing page at `/`, community form at `/submit`, editor behind
`/admin`. One Worker, one hostname. Attached with Workers **routes**, not a custom domain —
a custom domain refuses a hostname that already has a DNS record, and the zone came over from
Hostinger with its parking A record intact (error 100117). A route only needs the record to be
proxied, and then intercepts before the origin is ever reached, so the old Facebook forward
behind it is never hit.

Adding routes **disables the workers.dev subdomain**, which is why
`tagalogue-content.tight-unit-b07f.workers.dev` now returns Cloudflare's "nothing here yet".
That is correct: one canonical hostname, less surface.

`/robots.txt` and `/sitemap.xml` must stay in `isPublicPath`. Without them the middleware sends
crawlers to `/login`, Cloudflare's managed robots.txt fills the gap, and `/admin` ends up with
no `Disallow` at all.

**No social carousel.** Neither Instagram nor Facebook exposes a public post feed without an
API token — Instagram Basic Display is retired, and the Graph API needs a Business account, a
registered app and a refreshed long-lived token. Anything else is a scraper that breaks and
violates their terms. The site links to the accounts instead, and `sameAs` in the JSON-LD ties
them to the channel, which is what search engines actually read. A real feed is a day's work
plus a token to keep alive.

## Then, in order

**1 · Put it on tagalogue.tv — two dashboard steps.** The zone is already on the Cloudflare
account (`cb1e2423f99d55a7cd3bdc6faa577fc8`) but `initializing`: its nameservers have not been
switched, so it serves nothing yet.

- **Delete the imported parking records.** When the zone was added, Cloudflare copied
  Hostinger's records across — an `A` for `tagalogue.tv` (and probably `www`) pointing at
  `2.57.91.91`. A Workers custom domain cannot claim a hostname that already has one, so the
  deploy is refused with code 100117 until they are gone. *Cloudflare ▸ tagalogue.tv ▸ DNS.*
  **Leave any `MX` or `TXT` records alone** — those are email, not the parking page.
- **Point the nameservers at Cloudflare.** At Hostinger, replace `aster.dns-parking.com` /
  `helios.dns-parking.com` with:

  ```
  ajay.ns.cloudflare.com
  cecelia.ns.cloudflare.com
  ```

Then uncomment the `routes` block in `wrangler.jsonc` and `npm run deploy`. The site answers on
`tagalogue.tv` and `www.tagalogue.tv`.

**2 · Give the catalog its own hostname.** Viewers currently fetch it from
`pub-59f39c9e91c34695acada7303f42a801.r2.dev`, which works but is not yours and cannot be moved
later without rebuilding every installed app. Once the zone is active:

```
npx wrangler r2 bucket domain add tagalogue-media \
  --domain cdn.tagalogue.tv --zone-id cb1e2423f99d55a7cd3bdc6faa577fc8
```

Then set `TagalogueCatalogURL` to `https://cdn.tagalogue.tv/catalog.json` and
`TagalogueSubmitURL` to `https://tagalogue.tv/submit`, and rebuild the app. **Change both only
once the hostnames actually resolve** — a shipped app pointed at a dead catalog URL falls back
to an empty bundle and shows "Nothing on air yet".

**3 · Revoke the R2 S3 keys.** The Access Key ID and Secret Access Key are not used by the
Worker — it reaches the bucket through a binding the platform authenticates. They are still
wired into the Debug-only `Send` path on the television; if that goes, revoke them.

## Still open, not blocking Cloudflare

- **Terms and a report path — blocker for App Review.** The app solicits video from the public,
  so guideline 1.2 applies. Moderation is covered (nothing publishes unreviewed) and the submit
  page carries a consent line, but Apple will also expect published terms and a way for viewers
  to report content. Neither exists. This is a website-and-policy task, not a Cloudflare one.
- **Declining a submission should delete it from Stream.** Stream bills from the moment a video
  arrives, before anyone reviews it, so a declined clip costs money until it is removed.
- **Concurrent publishing can lose an episode.** Every write is read-modify-write on one
  `catalog.json`. With one or two editors this is unlikely; the fix is a conditional write
  (`If-Match` on the ETag, retry on 412).
- **Abandoned submissions accumulate.** A follower who starts an upload and closes the page
  leaves a record with no video. The queue hides them; nothing sweeps them up.
- **No rate limit on `/api/submit`.** Capped at 500 MB per video and it cannot publish anything,
  but a determined person could fill the bucket. Cloudflare's own rate limiting is the cheapest
  answer.
- **No audit trail.** Nothing records who published or removed what.
- **The Debug-only `Send` section.** Community superseded it. It still ships in Debug and is the
  only reason `NSLocalNetworkUsageDescription` is in the plist — an unused permission string in a
  Release build invites a question from App Review. Deleting `Services/Ingest/` and the `send`
  case is ~700 working lines, so it is your call.

## What it costs

- **Workers** — free tier likely covers a tool used by two people; Paid is $5/month.
- **R2** — 10 GB and 1M reads free, then $0.015/GB-month. The catalog and thumbnails round to nothing.
- **Stream** — the real cost: **$5 per 1,000 minutes stored** per month, **$1 per 1,000 minutes
  delivered**. Roughly $5/month for a sixteen-hour library.
