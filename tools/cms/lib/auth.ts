// Who is allowed to change the channel.
//
// Everything that publishes, edits, deletes or reviews is behind a password.
// Without this the tool is a public endpoint that can put anything on every
// Apple TV, or take the channel down, for anyone who finds the URL.
//
// The session is a signed value rather than a stored one — HMAC over an expiry
// with the password as the key — so there is no session table to run and the
// cookie cannot be forged without the password. Rotating `CMS_PASSWORD`
// invalidates every session at once, which is the behaviour you want.

const encoder = new TextEncoder()

export const SESSION_COOKIE = 'tltv_session'
const DAYS = 14

export function isConfigured(): boolean {
  return Boolean(process.env.CMS_PASSWORD)
}

function secret(): string {
  return process.env.CMS_PASSWORD ?? ''
}

async function sign(payload: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw', encoder.encode(secret()), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']
  )
  const mac = await crypto.subtle.sign('HMAC', key, encoder.encode(payload))
  return [...new Uint8Array(mac)].map((b) => b.toString(16).padStart(2, '0')).join('')
}

export async function issue(): Promise<{ value: string; maxAge: number }> {
  const expiry = Date.now() + DAYS * 86_400_000
  const payload = String(expiry)
  return { value: `${payload}.${await sign(payload)}`, maxAge: DAYS * 86_400 }
}

export async function isValid(cookie: string | undefined): Promise<boolean> {
  // An unset password must fail closed, not throw. A missing environment
  // variable should lock the tool, not take every page down with a 500.
  if (!isConfigured()) return false
  if (!cookie) return false
  const [payload, mac] = cookie.split('.')
  if (!payload || !mac) return false
  if (Number(payload) < Date.now()) return false

  const expected = await sign(payload)
  // Constant-time-ish: compare every character rather than bailing early.
  if (expected.length !== mac.length) return false
  let same = 0
  for (let i = 0; i < expected.length; i++) same |= expected.charCodeAt(i) ^ mac.charCodeAt(i)
  return same === 0
}

export function passwordMatches(given: string): boolean {
  const expected = process.env.CMS_PASSWORD ?? ''
  if (!expected || given.length !== expected.length) return false
  let same = 0
  for (let i = 0; i < expected.length; i++) same |= given.charCodeAt(i) ^ expected.charCodeAt(i)
  return same === 0
}

/**
 * What the public may reach without signing in.
 *
 * Deliberately a short list: the submission page followers are sent to, the
 * catalog the televisions read, and the media those catalogs point at. Nothing
 * on it can change what is on the channel.
 */
export function isPublicPath(pathname: string, method: string): boolean {
  // The public site. Everything the channel shows the world lives here; the
  // editor moved to /admin so that adding a public page can never widen the
  // hole around the tool.
  if (pathname === '/') return true
  if (pathname === '/submit') return true
  // Crawler-facing files. Without these the middleware sends a search engine to
  // /login, which means no sitemap and — worse — no Disallow on /admin.
  if (pathname === '/robots.txt' || pathname === '/sitemap.xml') return true
  // Published policies and the content-report path. App Review expects all of
  // these to be reachable without an account, and the report endpoint to work
  // for someone who has never signed in.
  if (['/privacy', '/terms', '/support', '/report'].includes(pathname)) return true
  if (pathname === '/api/report' && method === 'POST') return true
  if (pathname === '/login' || pathname === '/api/login') return true
  if (pathname.startsWith('/brand/')) return true
  // The favicon and the share card. Next serves these from the app directory
  // rather than /public, so they are real routes and deny-by-default caught
  // them: every link preview would have fetched the sign-in page.
  if (['/icon.png', '/apple-icon.png', '/opengraph-image.png'].includes(pathname)) return true
  if (pathname === '/api/submit' || pathname === '/api/submit/complete') return true
  // The television reads the catalog; it never writes.
  if (pathname === '/api/catalog' && method === 'GET') return true
  // Local mode serves video and thumbnails from here. Reads only — the PUT
  // that accepts an upload is handled separately, see below.
  if (pathname.startsWith('/api/media/') && (method === 'GET' || method === 'HEAD')) return true
  // A follower's upload target in local mode. In cloud mode the browser
  // uploads straight to Cloudflare and this route refuses everything.
  if (pathname.startsWith('/api/media/videos/') && (method === 'PUT' || method === 'OPTIONS')) return true
  if (pathname.startsWith('/api/video/') && method === 'GET') return true
  return false
}
