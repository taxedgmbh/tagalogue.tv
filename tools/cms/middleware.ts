import { NextRequest, NextResponse } from 'next/server'
import { SESSION_COOKIE, isConfigured, isPublicPath, isValid } from '@/lib/auth'

/**
 * Everything is closed unless `isPublicPath` says otherwise.
 *
 * A deny-by-default gate is the only kind worth having here: a new route added
 * next month is protected the moment it exists, rather than the moment someone
 * remembers to protect it.
 */
export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl
  if (isPublicPath(pathname, request.method)) return NextResponse.next()

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
