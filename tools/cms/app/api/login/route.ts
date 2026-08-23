import { NextRequest, NextResponse } from 'next/server'
import { SESSION_COOKIE, issue, passwordMatches } from '@/lib/auth'

export const dynamic = 'force-dynamic'

export async function POST(request: NextRequest) {
  if (!process.env.CMS_PASSWORD) {
    return NextResponse.json(
      { error: 'CMS_PASSWORD is not set on the server. Nobody can sign in until it is.' },
      { status: 500 }
    )
  }
  const { password } = (await request.json().catch(() => ({}))) as { password?: string }
  // A uniform delay so a wrong password cannot be distinguished by timing.
  await new Promise((r) => setTimeout(r, 400))
  if (!passwordMatches(String(password ?? ''))) {
    return NextResponse.json({ error: 'That is not the password.' }, { status: 401 })
  }
  const session = await issue()
  const response = NextResponse.json({ ok: true })
  response.cookies.set(SESSION_COOKIE, session.value, {
    httpOnly: true,
    sameSite: 'lax',
    secure: process.env.NODE_ENV === 'production',
    path: '/',
    maxAge: session.maxAge,
  })
  return response
}

export async function DELETE() {
  const response = NextResponse.json({ ok: true })
  response.cookies.set(SESSION_COOKIE, '', { path: '/', maxAge: 0 })
  return response
}
