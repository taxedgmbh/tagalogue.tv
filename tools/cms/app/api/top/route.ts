import { NextResponse } from 'next/server'
import { readCatalog, writeCatalog } from '@/lib/store'
import { minutesViewedByVideo, rankEpisodeIDs } from '@/lib/analytics'

export const dynamic = 'force-dynamic'

/**
 * Minutes viewed per episode over the last day and the last month, for the
 * editor's own table. Read-only — it changes nothing and writes nothing.
 *
 * Keyed by episode id rather than Stream uid so the caller does not have to
 * know that one is the other with a prefix.
 */
export async function GET() {
  const [day, month] = await Promise.all([
    minutesViewedByVideo(24),
    minutesViewedByVideo(24 * 30),
  ])

  if (day.error && month.error) {
    return NextResponse.json({ ok: false, error: day.error }, { status: 502 })
  }

  const asEpisodes = (m: Map<string, number>) =>
    Object.fromEntries([...m.entries()].map(([uid, minutes]) => [`cf-${uid}`, minutes]))

  return NextResponse.json({
    ok: true,
    day: asEpisodes(day.views),
    month: asEpisodes(month.views),
  })
}

/**
 * Recomputes "Top 10 today" and writes it into the catalog.
 *
 * Behind the editor's password like everything else that writes. There is
 * nothing secret in the result — it ends up in a public catalog a moment later
 * — but this rewrites the file every television reads, and that is not a thing
 * an anonymous caller should be able to make happen on demand.
 *
 * Called after a publish, and by the button in /admin. To make it genuinely
 * *daily* rather than "whenever the channel was touched", point a scheduler at
 * it; see PRODUCTION.md.
 */
export async function POST() {
  const catalog = await readCatalog()
  const ids = new Set(catalog.shows.flatMap((s) => s.episodes).map((e) => e.id))

  const { views, error } = await minutesViewedByVideo(24)

  if (error) {
    // Leave whatever chart is already there alone. A token that cannot read
    // analytics must not quietly empty the rail — that would look exactly like
    // "nobody watched anything today", which is a different and false claim.
    return NextResponse.json(
      { ok: false, error, hint: 'The Cloudflare token needs Account Analytics:Read in addition to Stream:Edit. Secrets need a redeploy to take effect.' },
      { status: 502 }
    )
  }

  const top = rankEpisodeIDs(views, ids, 10)

  // Absent, not empty: `topToday: []` and "no data yet" are the same thing to
  // the app, and absent is the honest encoding of both.
  const next = { ...catalog }
  if (top.length > 0) next.topToday = top
  else delete next.topToday

  await writeCatalog(next)
  return NextResponse.json({ ok: true, counted: views.size, top })
}
