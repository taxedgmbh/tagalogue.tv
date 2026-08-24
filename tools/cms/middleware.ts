import { NextRequest, NextResponse } from 'next/server'
import { SESSION_COOKIE, isConfigured, isPublicPath, isValid } from '@/lib/auth'

/**
 * Everything is closed unless `isPublicPath` says otherwise.
 *
 * A deny-by-default gate is the only kind worth having here: a new route added
 * next month is protected the moment it exists, rather than the moment someone
 * remembers to protect it.
 */
/**
 * Public pages worth caching at the edge. Deliberately a list rather than a
 * pattern: /submit and /report post forms, and /admin and /login must never be
 * held anywhere.
 */
const CACHEABLE = new Set(['/', '/privacy', '/terms', '/support'])

export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl
  if (isPublicPath(pathname, request.method)) {
    const response = NextResponse.next()

    // Let Cloudflare hold the public pages at the edge for a minute.
    //
    // The landing page is `force-dynamic` because it reads the live catalog,
    // which makes Next answer `no-store` — so every visitor, everywhere, waited
    // on an R2 round trip from Switzerland. Lighthouse measured 2.2s of that
    // under mobile throttling, and it was most of the Largest Contentful Paint.
    //
    // A minute is nothing against how often the channel changes, and
    // `stale-while-revalidate` means the first visitor after it lapses gets the
    // slightly-old copy instantly rather than waiting for a fresh one. The
    // televisions are unaffected: they read the bucket directly, never this.
    if (CACHEABLE.has(pathname) && request.method === 'GET') {
      response.headers.set(
        'Cache-Control',
        'public, max-age=0, s-maxage=60, stale-while-revalidate=600'
      )
    }
    return response
  }

  // Misconfiguration locks the tool rather than opening it, and says so
  // plainly instead of failing with a stack trace.
  if (!isConfigured()) {
    return NextResponse.json(
      { error: 'CMS_PASSWORD is not set on this deployment, so nobody can sign in.' },
      { status: 503 }
    )
  }

  if (await isValid(request.cookies.get(SESSION_COOKIE)?.value)) return NextResponse.next()

  if (pathname.startsWith('/api/')) {
    return NextResponse.json({ error: 'Not signed in.' }, { status: 401 })
  }
  const login = request.nextUrl.clone()
  login.pathname = '/login'
  login.search = pathname === '/' ? '' : `?next=${encodeURIComponent(pathname)}`
  return NextResponse.redirect(login)
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico).*)'],
}
