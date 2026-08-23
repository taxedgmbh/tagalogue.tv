import { initOpenNextCloudflareForDev } from '@opennextjs/cloudflare'

// Binds R2 and the vars in development, so `npm run dev` has a working MEDIA
// bucket with no Cloudflare account. Without it every page that reads the
// catalog 500s locally with "The MEDIA bucket is not bound". No-op in a
// production build.
initOpenNextCloudflareForDev()

/** @type {import('next').NextConfig} */
export default {
  // Next 16 writes its own AGENTS.md/CLAUDE.md; the repo already has one at the
  // root and a second, generated copy here only causes confusion.
  agentRules: false,
  // Videos go through route handlers, which stream them; the default 1 MB
  // body limit only applies to Server Actions, which this tool does not use.
  experimental: { serverActions: { bodySizeLimit: '2gb' } },
}
