import { NextResponse } from 'next/server'

export const dynamic = 'force-dynamic'

/**
 * What the header shows. Previously the editor called `upload-url` just to read
 * this back, which minted a Cloudflare upload every time the page loaded.
 */
export async function GET() {
  return NextResponse.json({ mode: 'cloudflare' })
}
