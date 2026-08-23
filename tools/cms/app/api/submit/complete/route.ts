import { NextRequest, NextResponse } from 'next/server'
import { readSubmissions, updateSubmission } from '@/lib/submissions'
import { videoDetails } from '@/lib/store'

export const dynamic = 'force-dynamic'

/**
 * Records that a follower's upload finished.
 *
 * Public, because the sender is not signed in — but deliberately narrow: it
 * takes an id and resolves the playback URL **server-side**, so a caller cannot
 * point a submission at a video of their choosing. It also refuses to touch
 * anything that is not still pending, so an approved item cannot be swapped out
 * from under the editor who approved it.
 */
export async function POST(request: NextRequest) {
  const { id } = (await request.json().catch(() => ({}))) as { id?: string }
  if (!id || typeof id !== 'string') {
    return NextResponse.json({ error: 'No id.' }, { status: 400 })
  }

  const existing = (await readSubmissions()).find((s) => s.id === id)
  if (!existing) return NextResponse.json({ error: 'No such submission.' }, { status: 404 })
  if (existing.state !== 'pending' || existing.videoURL) {
    return NextResponse.json({ error: 'That submission is already complete.' }, { status: 409 })
  }

  const uid = id.replace(/^sub-/, '')
  // Stream may still be encoding; the URL is valid either way, and the editor
  // will not see a playable preview until it is ready.
  const details = await videoDetails(uid)
  await updateSubmission(id, {
    videoURL: details.streamURL ?? '',
    durationSeconds: details.durationSeconds,
  })
  return NextResponse.json({ ok: true })
}
