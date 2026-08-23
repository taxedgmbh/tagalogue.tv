import type { Metadata } from 'next'
import { Archivo } from 'next/font/google'
import './globals.css'

// Archivo is the channel's face; the television bundles it, the web loads it.
// Nothing else in the interface uses a second family.
//
// Self-hosted and subset at build time rather than fetched from Google at
// runtime: the six static weights behind two preconnects were render-blocking
// and flashed the system sans before they landed. The variable axis covers
// 400–900 in one file.
const archivo = Archivo({
  subsets: ['latin'],
  weight: 'variable',
  display: 'swap',
  variable: '--font-archivo',
})

// The fallback title for any page that does not set its own. /submit and
// /login are client components and cannot export metadata, so they inherit
// this — and "Tagalogue TV · Content" was showing in the tab of a page the
// public is asked to fill in.
export const metadata: Metadata = {
  title: 'Tagalogue TV',
  description: 'A Filipino–Swiss channel from Biel/Bienne. Free on Apple TV.',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={archivo.variable}>
      <body>{children}</body>
    </html>
  )
}
