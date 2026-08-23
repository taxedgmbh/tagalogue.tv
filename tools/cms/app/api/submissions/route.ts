import { NextRequest, NextResponse } from 'next/server'
import { readSubmissions, updateSubmission } from '@/lib/submissions'

export const dynamic = 'force-dynamic'

/** The review queue. Editors only — this is not the public endpoint. */
export async function GET() {
  return NextResponse.json(await readSubmissions(), {
    headers: { 'Cache-Control': 'no-store' },
  })
}

/** Records the finished upload, or moves a submission through review. */
export async function PATCH(request: NextRequest) {
  const { id, ...changes } = (await request.json()) as { id?: string } & Record<string, unknown>
  if (!id) return NextResponse.json({ error: 'No id.' }, { status: 400 })
  const updated = await updateSubmission(id, changes)
  if (!updated) return NextResponse.json({ error: 'No such submission.' }, { status: 404 })
  return NextResponse.json(updated)
}
