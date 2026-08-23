import { NextRequest, NextResponse } from 'next/server'
import { readCatalog, writeCatalog } from '@/lib/store'
import { Episode, publicCatalog, withEpisode, withoutEpisode } from '@/lib/catalog'

export const dynamic = 'force-dynamic'

/**
 * The television reads this, and gets only what has actually been released.
 * Scheduling therefore needs nothing running on a timer: an episode dated in
 * the future is simply filtered out until its moment arrives.
 *
 * `?all=1` is the editor's view, which includes scheduled items.
 */
export async function GET(request: NextRequest) {
  const everything = await readCatalog()
  const wantsAll = new URL(request.url).searchParams.get('all') === '1'
  return NextResponse.json(wantsAll ? everything : publicCatalog(everything), {
    headers: { 'Cache-Control': 'no-store', 'Access-Control-Allow-Origin': '*' },
  })
}

/**
 * Anything written here has to be readable by the television, because the
 * television reads the bucket directly and has no way to ask for a correction.
 *
 * `Shared/Catalog.swift` declares `subtitles` and `chapters` non-optional, so
 * an episode without them is undecodable there. The app now drops an
 * unreadable episode rather than failing the whole catalog, but that is the
 * safety net — this is the place to not write one in the first place.
 */
function sanitise(input: Episode): { episode?: Episode; error?: string } {
  if (!input?.id) return { error: 'An episode needs an id.' }
  if (!input.streamURL) return { error: 'An episode needs a stream URL.' }
  if (!input.showID) return { error: 'An episode needs a strand (showID).' }
  if (!input.title?.trim()) return { error: 'An episode needs a title.' }

  return {
    episode: {
      ...input,
      showTitle: input.showTitle ?? '',
      synopsis: input.synopsis ?? '',
      number: Number.isFinite(input.number) ? input.number : 0,
      duration: Number.isFinite(input.duration) ? input.duration : 0,
      isNew: input.isNew ?? false,
      // The two the Swift model cannot do without.
      subtitles: Array.isArray(input.subtitles) ? input.subtitles : [],
      chapters: Array.isArray(input.chapters) ? input.chapters : [],
    },
  }
}

export async function POST(request: NextRequest) {
  const { episode, error } = sanitise((await request.json()) as Episode)
  if (error || !episode) return NextResponse.json({ error }, { status: 400 })

  const catalog = withEpisode(await readCatalog(), episode)
  await writeCatalog(catalog)
  return NextResponse.json(catalog)
}

export async function DELETE(request: NextRequest) {
  const id = new URL(request.url).searchParams.get('id')
  if (!id) return NextResponse.json({ error: 'No id.' }, { status: 400 })
  const catalog = withoutEpisode(await readCatalog(), id)
  await writeCatalog(catalog)
  return NextResponse.json(catalog)
}
