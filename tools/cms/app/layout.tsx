import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'Tagalogue TV · Content',
  description: 'Upload, describe and publish episodes to the channel.',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <head>
        {/* Archivo is the channel's face; the television bundles it, the web
            loads it. Nothing else in the interface uses a second family. */}
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="" />
        <link
          href="https://fonts.googleapis.com/css2?family=Archivo:wght@400;500;600;700;800;900&display=swap"
          rel="stylesheet"
        />
      </head>
      <body>{children}</body>
    </html>
  )
}
