// Content reports — the way a viewer tells us something should not be on the
// channel.
//
// App Review guideline 1.2 expects an app that carries user-generated content
// to give people a mechanism for reporting it, and expects that mechanism to
// reach a human. This is that mechanism: a report lands in a private queue and
// shows up in the editor beside the submissions.
//
// Kept separate from submissions on purpose. A submission is someone offering
// content; a report is someone objecting to it. They have different urgency
// and neither should be able to hide the other.

import { readObjectText, writeObjectText } from './store'

export type ReportState = 'open' | 'actioned' | 'dismissed'

export type Report = {
  id: string
  /** Which episode, if the reporter picked one. Free text otherwise. */
  episodeID?: string | null
  /** What is wrong with it, in the reporter's words. */
  reason: string
  detail?: string | null
  /** Optional: only so we can come back with a question. Never published. */
  contact?: string | null
  reportedAt: string
  state: ReportState
  /** An editor's note. Internal. */
  note?: string | null
}

/** Private, like the submission queue: never served from the public bucket. */
const KEY = 'private/reports.json'

export async function readReports(): Promise<Report[]> {
  const body = await readObjectText(KEY)
  if (!body) return []
  try { return JSON.parse(body) as Report[] } catch { return [] }
}

export async function writeReports(list: Report[]): Promise<void> {
  await writeObjectText(KEY, JSON.stringify(list, null, 2), 'application/json')
}

export async function addReport(report: Report): Promise<void> {
  const all = await readReports()
  all.unshift(report)
  await writeReports(all)
}

export const REPORT_REASONS = [
  'Hateful, abusive or discriminatory',
  'Violent or graphic',
  'Sexual content',
  'Harassment of a person',
  'Copyright — this is my work',
  'Private information about someone',
  'Misleading or false',
  'Something else',
] as const
