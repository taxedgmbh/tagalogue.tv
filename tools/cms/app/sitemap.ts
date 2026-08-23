import type { MetadataRoute } from 'next'

export default function sitemap(): MetadataRoute.Sitemap {
  return [
    { url: 'https://tagalogue.tv/', changeFrequency: 'weekly', priority: 1 },
    { url: 'https://tagalogue.tv/submit', changeFrequency: 'monthly', priority: 0.5 },
    { url: 'https://tagalogue.tv/support', changeFrequency: 'monthly', priority: 0.4 },
    { url: 'https://tagalogue.tv/privacy', changeFrequency: 'yearly', priority: 0.3 },
    { url: 'https://tagalogue.tv/terms', changeFrequency: 'yearly', priority: 0.3 },
    { url: 'https://tagalogue.tv/report', changeFrequency: 'yearly', priority: 0.3 },
  ]
}
