import { NextRequest, NextResponse } from 'next/server'
import { putThumbnail } from '@/lib/store'

export const dynamic = 'force-dynamic'

/** A frame grabbed in the browser, or an image the operator chose. */
export async function POST(request: NextRequest) {
  const uid = new URL(request.url).searchParams.get('uid')
  if (!uid) return NextResponse.json({ error: 'No uid.' }, { status: 400 })
  try {
    const url = await putThumbnail(uid, await request.arrayBuffer())
    return NextResponse.json({ url })
  } catch (error) {
    return NextResponse.json({ error: (error as Error).message }, { status: 500 })
  }
}
