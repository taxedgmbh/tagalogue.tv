import { NextRequest, NextResponse } from 'next/server'
import { addReport, REPORT_REASONS, type Report } from '@/lib/reports'

export const dynamic = 'force-dynamic'

/**
 * Public on purpose: a viewer must be able to report something without an
 * account. Rate limiting belongs in front of this (Cloudflare), not in it.
 */
export async function POST(request: NextRequest) {
  const body = (await request.json().catch(() => ({}))) as Partial<Report>

  const reason = String(body.reason ?? '').trim()
  if (!reason) return NextResponse.json({ error: 'Choose a reason.' }, { status: 400 })
  if (!(REPORT_REASONS as readonly string[]).includes(reason)) {
    return NextResponse.json({ error: 'Unknown reason.' }, { status: 400 })
  }

  const clip = (v: unknown, n: number) => String(v ?? '').trim().slice(0, n) || null

  await addReport({
    id: crypto.randomUUID(),
    episodeID: clip(body.episodeID, 120),
    reason,
    detail: clip(body.detail, 4000),
    contact: clip(body.contact, 200),
    reportedAt: new Date().toISOString(),
    state: 'open',
  })

  return NextResponse.json({ ok: true })
}
