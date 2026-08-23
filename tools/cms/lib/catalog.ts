// The catalog schema, kept identical to Shared/Catalog.swift in the tvOS app.
// The television decodes exactly this, so a field renamed here is a field the
// channel stops showing. Dates are ISO-8601 because that is what the Swift
// decoder is configured for.

export type Chapter = { id: string; title: string; start: number }

export type Episode = {
  id: string
  showID: string
  showTitle: string
  /** 0 means unnumbered — the vlogs convention. Never render "EP 0". */
  number: number
  title: string
  synopsis: string
  /** Seconds. The catalog is the authority on length, not the stream. */
  duration: number
  streamURL: string
  subtitles: string[]
  isNew: boolean
  chapters: Chapter[]
  artworkResource?: string | null
  /**
   * When this becomes visible. A time in the future means scheduled: the
   * television hides it until then, so nothing has to run on a timer to make
   * a release happen.
   */
  publishedAt?: string | null
  /**
   * When it stops being available. Absent means forever, which is the normal
   * case. Rights windows, seasonal pieces and anything time-limited get one.
   */
  expiresAt?: string | null
  /**
   * Non-destructive trim, in seconds from the start of the file. The original
   * upload is never re-encoded — the player simply starts here and stops at
   * `trimEnd`, so a cut can be adjusted or undone at any time.
   */
  trimStart?: number | null
  trimEnd?: number | null

  /**
   * public   — in the rails, in search, on the Top Shelf.
   * unlisted — playable by direct link, but never listed anywhere.
   * draft    — not published at all; the editor's own working copy.
   */
  visibility?: Visibility | null
  /** Free-text keywords. The television searches these along with the title. */
  tags?: string[] | null
  /** Drives nothing automatically — it is metadata a parent control can read. */
  maturity?: Maturity | null
  /** A collection this belongs to, beyond its strand. */
  seriesID?: string | null
  seriesTitle?: string | null
  /** Caption tracks. `subtitles` holds the language codes the card advertises. */
  captions?: Caption[] | null
}

export type Visibility = 'public' | 'unlisted' | 'draft'
export type Maturity = 'general' | 'teen' | 'mature'
export type Caption = { lang: string; label: string; url: string }

export const VISIBILITIES: { id: Visibility; title: string; note: string }[] = [
  { id: 'public', title: 'Public', note: 'Listed everywhere on the channel.' },
  { id: 'unlisted', title: 'Unlisted', note: 'Playable by direct link only — never listed.' },
  { id: 'draft', title: 'Draft', note: 'Yours only. Nothing on the television sees it.' },
]

export const MATURITIES: { id: Maturity; title: string }[] = [
  { id: 'general', title: 'General' },
  { id: 'teen', title: 'Teen' },
  { id: 'mature', title: '18+' },
]

export const LANGUAGES = [
  { code: 'en', label: 'English' },
  { code: 'tl', label: 'Tagalog' },
  { code: 'de', label: 'German' },
  { code: 'fr', label: 'French' },
] as const

export type Show = { id: string; title: string; subtitle: string; episodes: Episode[] }
export type Catalog = {
  shows: Show[]
  /**
   * Episode ids, most watched first, over the last day. Written by
   * `POST /api/top` from Cloudflare's server-side Stream totals — never from
   * anything a television reports, because a television reports nothing.
   *
   * Optional, and absent rather than empty when the numbers cannot be read:
   * the app draws no chart at all instead of an empty or invented one.
   */
  topToday?: string[]
}

export const STRANDS = [
  { id: 'interviews', title: 'Interviews', subtitle: 'Sit-down conversations, recorded across Switzerland' },
  { id: 'vlogs', title: 'Vlogs', subtitle: 'Life between two countries, as it happens' },
] as const

/**
 * The strand approved community videos land in.
 *
 * Lives here rather than in `submissions.ts` because the editor — a client
 * component — needs it to name a strand, and importing it from there would
 * drag the R2 store into the browser bundle.
 */
export const COMMUNITY_STRAND = {
  id: 'community',
  title: 'Community',
  subtitle: 'Sent in by the people who watch',
}

export const emptyCatalog: Catalog = { shows: [] }

/**
 * Adds or replaces an episode, newest first within its strand.
 *
 * The id is removed from **every** strand first, not just the target one.
 * Filtering only the destination meant that moving an episode from Interviews
 * to Vlogs left the old copy behind, and the same id existed twice — which the
 * television would then show twice.
 */
export function withEpisode(catalog: Catalog, episode: Episode): Catalog {
  const shows = catalog.shows.map((s) => ({
    ...s,
    episodes: s.episodes.filter((e) => e.id !== episode.id),
  }))

  const strand = STRANDS.find((s) => s.id === episode.showID)
  let show = shows.find((s) => s.id === episode.showID)

  if (!show) {
    show = {
      id: episode.showID,
      title: strand?.title ?? episode.showTitle,
      subtitle: strand?.subtitle ?? `${episode.showTitle} from the channel`,
      episodes: [],
    }
    shows.push(show)
  }
  show.episodes = [episode, ...show.episodes]
  show.title = strand?.title ?? show.title

  // A strand nobody is in should not linger in the catalog.
  return { ...catalog, shows: shows.filter((s) => s.episodes.length > 0) }
}

export function withoutEpisode(catalog: Catalog, id: string): Catalog {
  return {
    ...catalog,
    shows: catalog.shows
      .map((s) => ({ ...s, episodes: s.episodes.filter((e) => e.id !== id) }))
      .filter((s) => s.episodes.length > 0),
  }
}

/** True when this is still waiting for its release time. */
export function isScheduled(episode: Episode, now = new Date()): boolean {
  if (!episode.publishedAt) return false
  return new Date(episode.publishedAt).getTime() > now.getTime()
}

export function visibilityOf(episode: Episode): Visibility {
  return episode.visibility ?? 'public'
}

/** True once its window has closed. No expiry means it never closes. */
export function isExpired(episode: Episode, now = new Date()): boolean {
  if (!episode.expiresAt) return false
  return new Date(episode.expiresAt).getTime() <= now.getTime()
}

/** Days left in the window, or null when there is no end to it. */
export function daysRemaining(episode: Episode, now = new Date()): number | null {
  if (!episode.expiresAt) return null
  const ms = new Date(episode.expiresAt).getTime() - now.getTime()
  return Math.ceil(ms / 86_400_000)
}

/** The single word the editor's list shows for where this stands. */
export function statusOf(episode: Episode, now = new Date()):
  { label: string; tone: 'live' | 'scheduled' | 'draft' | 'unlisted' | 'expired' } {
  const visibility = visibilityOf(episode)
  if (visibility === 'draft') return { label: 'Draft', tone: 'draft' }
  // Expiry outranks everything except being a draft: a closed window is a
  // closed window, whether or not it was ever listed.
  if (isExpired(episode, now)) return { label: 'Expired', tone: 'expired' }
  if (isScheduled(episode, now)) return { label: 'Scheduled', tone: 'scheduled' }
  if (visibility === 'unlisted') return { label: 'Unlisted', tone: 'unlisted' }
  return { label: 'Public', tone: 'live' }
}

/**
 * What the television is allowed to see.
 *
 * Drafts never leave this building. Scheduled episodes are held until their
 * moment. Unlisted ones *are* included — the television needs them to honour a
 * direct link — but it keeps them out of every list itself.
 */
export function publicCatalog(catalog: Catalog, now = new Date()): Catalog {
  return {
    ...catalog,
    shows: catalog.shows
      .map((s) => ({
        ...s,
        episodes: s.episodes.filter(
          (e) => visibilityOf(e) !== 'draft' && !isScheduled(e, now) && !isExpired(e, now)
        ),
      }))
      .filter((s) => s.episodes.length > 0),
  }
}

/** Playing length after the trim, which is what viewers actually get. */
export function playingSeconds(episode: Episode): number {
  const start = episode.trimStart ?? 0
  const end = episode.trimEnd ?? episode.duration
  return Math.max(1, Math.round(end - start))
}

export function allEpisodes(catalog: Catalog): Episode[] {
  return catalog.shows
    .flatMap((s) => s.episodes)
    .sort((a, b) => (b.publishedAt ?? '').localeCompare(a.publishedAt ?? ''))
}

export function durationLabel(seconds: number): string {
  if (seconds < 60) return `${seconds} sec`
  const m = Math.round(seconds / 60)
  return `${m} min`
}
