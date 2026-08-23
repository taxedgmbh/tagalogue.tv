import { NextRequest, NextResponse } from 'next/server'
import { addSubmission } from '@/lib/submissions'
import { createUpload } from '@/lib/store'

export const dynamic = 'force-dynamic'

/**
 * Open to the public — this is what the QR code on the television leads to.
 *
 * Two deliberate limits, because an unauthenticated upload endpoint is a
 * standing invitation: a submission is capped in length, and it is created in
 * the `pending` state and can only leave it by hand. Nothing here can put
 * anything on a television by itself.
 */
export async function POST(request: NextRequest) {
  try {
    const body = (await request.json()) as Record<string, unknown>
    const name = String(body.name ?? '').trim().slice(0, 60)
    const message = String(body.message ?? '').trim().slice(0, 600)
    const place = String(body.place ?? '').trim().slice(0, 60)

    if (!name) return NextResponse.json({ error: 'Please give a name.' }, { status: 400 })
    if (!message) return NextResponse.json({ error: 'Please write a message.' }, { status: 400 })

    const upload = await createUpload()
    const id = `sub-${upload.uid}`

    await addSubmission({
      id,
      name,
      place: place || null,
      message,
      videoURL: '',              // filled in once the upload finishes
      submittedAt: new Date().toISOString(),
      state: 'pending',
    })

    return NextResponse.json({ id, uid: upload.uid, uploadURL: upload.uploadURL })
  } catch (error) {
    // Public endpoint: a follower gets something they can act on, and the real
    // cause goes to the logs. Server messages here name environment variables
    // and account ids, which is not a stranger's business.
    console.error('submission failed:', error)
    return NextResponse.json(
      { error: 'We could not accept that just now. Please try again in a minute.' },
      { status: 503 }
    )
  }
}
