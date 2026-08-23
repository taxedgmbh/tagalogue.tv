import type { MetadataRoute } from 'next'

export default function sitemap(): MetadataRoute.Sitemap {
  return [
    { url: 'https://tagalogue.tv/', changeFrequency: 'weekly', priority: 1 },
    { url: 'https://tagalogue.tv/submit', changeFrequency: 'monthly', priority: 0.5 },
  ]
}
