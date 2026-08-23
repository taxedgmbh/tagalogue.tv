import { NextResponse } from 'next/server'
import { thumbnailAt, videoDetails } from '@/lib/store'

export const dynamic = 'force-dynamic'

/** Polled while Cloudflare encodes. Local mode is ready immediately. */
export async function GET(
  request: Request,
  { params }: { params: Promise<{ uid: string }> }
) {
  const { uid } = await params
  const seconds = Number(new URL(request.url).searchParams.get('t') ?? '10')

  const details = await videoDetails(uid)
  return NextResponse.json({
    status: details.status,
    streamURL: details.streamURL,
    thumbnailURL: thumbnailAt(details.thumbnailBase, seconds),
    durationSeconds: details.durationSeconds,
    pctComplete: details.pctComplete,
  })
}
