import type { MetadataRoute } from 'next'

// /admin must never be indexed; everything public should be.
export default function robots(): MetadataRoute.Robots {
  return {
    rules: [{ userAgent: '*', allow: '/', disallow: ['/admin', '/login', '/api/'] }],
    sitemap: 'https://tagalogue.tv/sitemap.xml',
  }
}
