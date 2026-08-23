import { initOpenNextCloudflareForDev } from '@opennextjs/cloudflare'

// Binds R2 and the vars in development, so `npm run dev` has a working MEDIA
// bucket with no Cloudflare account. Without it every page that reads the
// catalog 500s locally with "The MEDIA bucket is not bound". No-op in a
// production build.
initOpenNextCloudflareForDev()

// …and put `.dev.vars` on `process.env` while developing.
//
// `initOpenNextCloudflareForDev` binds R2 and the vars onto
// `getCloudflareContext().env`, which is where `lib/store.ts` looks. But
// `lib/auth.ts` reads `process.env.CMS_PASSWORD` directly — it has to, because
// `middleware.ts` imports it and must not pull the Cloudflare context into the
// middleware runtime. In the deployed Worker the two are the same object, so
// only `npm run dev` was affected: signing in locally answered "CMS_PASSWORD is
// not set on the server" no matter what was in `.dev.vars`.
//
// Development only, and never overwrites a value already in the environment.
if (process.env.NODE_ENV !== 'production') {
  const { readFileSync, existsSync } = await import('node:fs')
  const file = new URL('./.dev.vars', import.meta.url)
  if (existsSync(file)) {
    for (const line of readFileSync(file, 'utf8').split('\n')) {
      const match = /^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$/.exec(line)
      if (!match || line.trimStart().startsWith('#')) continue
      const value = match[2].trim().replace(/^["'](.*)["']$/, '$1')
      if (process.env[match[1]] === undefined) process.env[match[1]] = value
    }
  }
}

/** @type {import('next').NextConfig} */
export default {
  // Next 16 writes its own AGENTS.md/CLAUDE.md; the repo already has one at the
  // root and a second, generated copy here only causes confusion.
  agentRules: false,
  // Videos go through route handlers, which stream them; the default 1 MB
  // body limit only applies to Server Actions, which this tool does not use.
  experimental: { serverActions: { bodySizeLimit: '2gb' } },
}
