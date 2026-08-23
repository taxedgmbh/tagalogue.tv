import { NextRequest, NextResponse } from 'next/server'
import { createUpload } from '@/lib/store'

export const dynamic = 'force-dynamic'

/**
 * Hands the browser somewhere to send the video.
 *
 * In cloud mode that is a Cloudflare Direct Creator Upload URL, so the bytes
 * go straight to Stream and never through this server. In local mode it is a
 * route on this server that writes to .data/videos.
 */
export async function POST(_request: NextRequest) {
  try {
    const upload = await createUpload()
    return NextResponse.json(upload)
  } catch (error) {
    return NextResponse.json({ error: (error as Error).message }, { status: 500 })
  }
}
