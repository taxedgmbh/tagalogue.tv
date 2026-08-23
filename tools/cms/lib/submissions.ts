// Community submissions — what followers send in from the QR code on screen.
//
// Deliberately a separate store from the catalog. A submission is not an
// episode: it has a sender, it has a state, and it has not been looked at yet.
// Nothing here reaches a television until somebody approves it, which is both
// the editorial position and the only defensible one for an app that solicits
// video from the public.

import { readObjectText, writeObjectText } from './store'

export type SubmissionState = 'pending' | 'approved' | 'rejected'

export type Submission = {
  id: string
  /** What the sender called themselves. Not verified, and shown as given. */
  name: string
  /** Where they are writing from, if they said. */
  place?: string | null
  /** Their message — the "thought" they are sharing. */
  message: string
  videoURL: string
  thumbnailURL?: string | null
  durationSeconds?: number | null
  submittedAt: string
  state: SubmissionState
  /** Set when an editor turns it into an episode. */
  publishedEpisodeID?: string | null
  /** Why it was turned down. Never shown to the sender; it is a note to self. */
  note?: string | null
}

/**
 * Where the queue lives. Private: never linked publicly and never served from
 * the bucket's public URL — a queue of unreviewed video from strangers is not
 * something to leave open.
 */
const KEY = 'private/submissions.json'

export async function readSubmissions(): Promise<Submission[]> {
  const body = await readObjectText(KEY)
  if (!body) return []
  try { return JSON.parse(body) as Submission[] } catch { return [] }
}

export async function writeSubmissions(list: Submission[]): Promise<void> {
  await writeObjectText(KEY, JSON.stringify(list, null, 2), 'application/json')
}

export async function addSubmission(submission: Submission): Promise<void> {
  const list = await readSubmissions()
  await writeSubmissions([submission, ...list])
}

export async function updateSubmission(
  id: string,
  changes: Partial<Submission>
): Promise<Submission | null> {
  const list = await readSubmissions()
  const index = list.findIndex((s) => s.id === id)
  if (index < 0) return null
  list[index] = { ...list[index], ...changes }
  await writeSubmissions(list)
  return list[index]
}

/**
 * The strand approved community videos land in.
 *
 * Defined in `catalog.ts` and re-exported here, so the editor can import it
 * without pulling this module — and the R2 store it depends on — into the
 * browser.
 */
export { COMMUNITY_STRAND } from './catalog'
