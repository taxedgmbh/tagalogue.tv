import { NextRequest, NextResponse } from 'next/server'
import { putCaption } from '@/lib/store'

export const dynamic = 'force-dynamic'

/**
 * A WebVTT track for one language.
 *
 * On Cloudflare this goes to Stream, which folds it into the HLS manifest so
 * the television's own subtitle menu picks it up with no extra work. In local
 * mode the file is stored and listed, but AVPlayer cannot side-load a caption
 * file onto a progressive MP4 — that only works once the video is real HLS.
 */
export async function POST(request: NextRequest) {
  const url = new URL(request.url)
  const uid = url.searchParams.get('uid')
  const lang = url.searchParams.get('lang')
  if (!uid || !lang) {
    return NextResponse.json({ error: 'Needs a uid and a language.' }, { status: 400 })
  }
  try {
    const stored = await putCaption(uid, lang, await request.text())
    return NextResponse.json({ url: stored, lang })
  } catch (error) {
    return NextResponse.json({ error: (error as Error).message }, { status: 500 })
  }
}
