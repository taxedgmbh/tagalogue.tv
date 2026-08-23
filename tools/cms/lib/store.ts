// Storage: Cloudflare Stream for video, R2 for everything else.
//
// R2 is reached through a **binding**, not the S3 API. A Worker with a bound
// bucket is authenticated by the platform, so there is no access key, no secret
// key, and no request signing — roughly 120 lines of SigV4 and two long-lived
// credentials that no longer exist to be leaked.
//
// There is deliberately no local filesystem mode. Workers has no filesystem, and
// carrying a second storage backend purely to satisfy development is how the
// television ended up writing uploads to a directory tvOS wipes. OpenNext
// simulates R2 locally, so `npm run dev` has a working bucket with no
// credentials; only video needs the real Stream account.

import { getCloudflareContext } from '@opennextjs/cloudflare'
import { Catalog, emptyCatalog } from './catalog'

/** The object key the published catalog lives under. Public. */
export const CATALOG_KEY = 'catalog.json'

function bucket(): R2Bucket {
  const bound = getCloudflareContext().env.MEDIA as R2Bucket | undefined
  if (!bound) throw new Error('The MEDIA bucket is not bound. Check wrangler.jsonc.')
  return bound
}

export function env(name: string): string {
  const context = getCloudflareContext().env as unknown as Record<string, string | undefined>
  const value = context[name] ?? process.env[name]
  if (!value) throw new Error(`${name} is not set. See .dev.vars.example.`)
  return value
}

function optional(name: string): string | undefined {
  const context = getCloudflareContext().env as unknown as Record<string, string | undefined>
  return context[name] ?? process.env[name]
}

/** Where viewers read the catalog from. Falls back to this Worker's own origin. */
export function publicBase(): string {
  return (optional('R2_PUBLIC_BASE_URL') ?? '').replace(/\/$/, '')
}

// ── Catalog ────────────────────────────────────────────────────────────────

export async function readCatalog(): Promise<Catalog> {
  const object = await bucket().get(CATALOG_KEY)
  if (!object) return emptyCatalog
  try {
    return JSON.parse(await object.text()) as Catalog
  } catch {
    // A corrupt catalog must not blank the channel; the televisions keep their
    // cached copy and the editor sees an empty list rather than a crash.
    return emptyCatalog
  }
}

export async function writeCatalog(catalog: Catalog): Promise<void> {
  await bucket().put(CATALOG_KEY, JSON.stringify(catalog, null, 2), {
    httpMetadata: {
      contentType: 'application/json',
      // R2 serves this from the edge. Without a short max-age a publish can
      // take a long while to reach anyone.
      cacheControl: 'public, max-age=60',
    },
  })
}

// ── Small private objects (the submission queue) ───────────────────────────

export async function readObjectText(key: string): Promise<string | null> {
  const object = await bucket().get(key)
  return object ? object.text() : null
}

export async function writeObjectText(key: string, body: string, contentType: string): Promise<void> {
  await bucket().put(key, body, { httpMetadata: { contentType } })
}

// ── Media ──────────────────────────────────────────────────────────────────

/**
 * A one-time URL the browser uploads straight to. The video never passes
 * through this Worker, which is why it can stay small.
 */
export async function createUpload(): Promise<{ uid: string; uploadURL: string }> {
  const result = await cf(`/accounts/${env('STREAM_ACCOUNT_ID')}/stream/direct_upload`, {
    method: 'POST',
    body: JSON.stringify({ maxDurationSeconds: 21600, requireSignedURLs: false }),
  })
  return { uid: result.uid, uploadURL: result.uploadURL }
}

export async function putThumbnail(uid: string, body: ArrayBuffer): Promise<string> {
  const key = `thumbnails/${uid}.jpg`
  await bucket().put(key, body, {
    httpMetadata: { contentType: 'image/jpeg', cacheControl: 'public, max-age=31536000' },
  })
  return `${publicBase()}/${key}`
}

/**
 * What Stream says about a video, including the URLs to play it.
 *
 * The playback and thumbnail URLs come **from Cloudflare's own response**
 * rather than being assembled from a configured `customer-<CODE>` subdomain.
 * That removes a setting that has to be copied correctly out of the dashboard,
 * and with it a whole class of failure where every URL is subtly wrong.
 */
export async function videoDetails(uid: string): Promise<{
  status: 'ready' | 'processing' | 'error'
  streamURL: string | null
  thumbnailBase: string | null
  durationSeconds: number | null
  /** How far Stream is through encoding, 0–100. Null before it starts. */
  pctComplete: number | null
}> {
  try {
    const result = await cf(`/accounts/${env('STREAM_ACCOUNT_ID')}/stream/${uid}`)
    const state = result?.status?.state
    // Stream reports this as a string, and omits it entirely before encoding
    // starts. The editor draws a progress bar from it, so anything unparseable
    // has to come back as null rather than NaN.
    const pct = Number(result?.status?.pctComplete)
    return {
      status: state === 'ready' ? 'ready' : state === 'error' ? 'error' : 'processing',
      streamURL: result?.playback?.hls ?? null,
      thumbnailBase: result?.thumbnail ?? null,
      durationSeconds: typeof result?.duration === 'number' ? result.duration : null,
      pctComplete: Number.isFinite(pct) ? Math.max(0, Math.min(100, pct)) : null,
    }
  } catch {
    return {
      status: 'processing', streamURL: null, thumbnailBase: null,
      durationSeconds: null, pctComplete: null,
    }
  }
}

/** Stream renders a thumbnail at any timestamp, so a chosen frame costs nothing. */
export function thumbnailAt(base: string | null, seconds: number): string | null {
  if (!base) return null
  return `${base}?time=${Math.round(seconds)}s&width=1280&fit=crop`
}

/** Stream bills per minute stored, so a declined submission should not linger. */
export async function deleteVideo(uid: string): Promise<void> {
  try {
    await cf(`/accounts/${env('STREAM_ACCOUNT_ID')}/stream/${uid}`, { method: 'DELETE' })
  } catch {
    // Already gone, or never finished uploading. Not worth failing a decline.
  }
}

export async function putCaption(uid: string, lang: string, vtt: string): Promise<string> {
  const form = new FormData()
  form.append('file', new Blob([vtt], { type: 'text/vtt' }), `${lang}.vtt`)

  const res = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${env('STREAM_ACCOUNT_ID')}/stream/${uid}/captions/${lang}`,
    { method: 'PUT', headers: { Authorization: `Bearer ${env('CF_API_TOKEN')}` }, body: form }
  )
  const json = (await res.json()) as { success?: boolean; errors?: { message: string }[] }
  if (!res.ok || json.success === false) {
    throw new Error(json.errors?.map((e) => e.message).join(', ') ?? `Cloudflare returned ${res.status}`)
  }
  // Captions ride inside the HLS manifest, which is what makes them appear in
  // the television's own subtitle menu. The sidecar URL below is derived from
  // the video's own playback URL rather than a configured `customer-<CODE>`
  // subdomain — the same reason `videoDetails` does: one less setting to copy
  // out of the dashboard, and one less way for every URL to be subtly wrong.
  const { streamURL } = await videoDetails(uid)
  return streamURL
    ? streamURL.replace(/\/manifest\/video\.m3u8$/, `/captions/${lang}.vtt`)
    : ''
}

// ── Cloudflare API ─────────────────────────────────────────────────────────

async function cf(pathname: string, init: RequestInit = {}) {
  const res = await fetch(`https://api.cloudflare.com/client/v4${pathname}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${env('CF_API_TOKEN')}`,
      'Content-Type': 'application/json',
      ...(init.headers ?? {}),
    },
  })
  const json = (await res.json()) as {
    success?: boolean; result?: any; errors?: { message: string }[]
  }
  if (!res.ok || json.success === false) {
    throw new Error(
      json.errors?.map((e) => e.message).join(', ') || `Cloudflare returned ${res.status}`
    )
  }
  return json.result
}
